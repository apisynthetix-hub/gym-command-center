// lib/gym_command_center.dart
import 'dart:io' show File;
import 'dart:math' as math;
import 'dart:convert';
import 'dart:async';
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
import 'package:url_launcher/url_launcher.dart';
import 'supabase_config.dart';
import 'theme.dart';
import 'theme_controller.dart';
import 'home_mobile.dart';

enum UserRole { none, admin, client }

class GymCommandCenter extends StatefulWidget {
  const GymCommandCenter({super.key});
  @override
  State<GymCommandCenter> createState() => _GymCommandCenterState();
}

class _GymCommandCenterState extends State<GymCommandCenter>
    with TickerProviderStateMixin {
  UserRole currentRole = UserRole.none;
  Map<String, dynamic>? loggedClient;
  String adminPin = '1234';
  int pinAttempts = 0;
  DateTime? pinLockedUntil;
  final TextEditingController pinController = TextEditingController();
  final TextEditingController clientCedulaController = TextEditingController();

  final TextEditingController regNameController = TextEditingController();
  final TextEditingController regCedulaController = TextEditingController();
  final TextEditingController regPhoneController = TextEditingController();
  String regSelectedPlan = '';
  bool regLoading = false;

  String loginScreen = 'choose';
  int _section = 0;
  final List<int> _sectionHistory = [];

  int capacity = 150;
  int inside = 0;
  bool loadingCheckins = false;
  int clientInsideCount = 0;
  bool clientLoadingAforo = false;
  int clientCapacity = 150;
  Timer? _aforoTimer;
  int clientStreak = 0;
  List<String> clientCheckinDates = [];

  double income = 0;
  int activeMembers = 0;
  String selectedCurrency = 'USD';
  bool showConversion = true;
  double usdToVes = 40.00;
  double eurToVes = 43.50;
  double copToVes = 0.01;
  String gymPhone = '+58 412 000 0000';

  final ScreenshotController _qrScreenshotController = ScreenshotController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController searchController = TextEditingController();

  String alertFilter = 'TODAS';
  Set<String> dismissedAlerts = {};
  String dismissedDate = '';

  String clientFilter = 'TODOS';
  String qrMode = 'DIARIO';
  String qrToken = '';
  DateTime qrGenerated = DateTime.now();
  DateTime qrExpires = DateTime.now();
  String financePeriod = 'MES';
  String transactionFilter = 'TODOS';
  int trainingTab = 0;
  String exerciseFilter = 'TODOS';
  bool loadingData = true;
  bool _qrProcessing = false;

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
  List<Map<String, dynamic>> renewalRequests = [];

  final List<Map<String, String>> availableCurrencies = [
    {'code': 'USD', 'name': 'Dólar', 'symbol': '\$'},
    {'code': 'EUR', 'name': 'Euro', 'symbol': '€'},
    {'code': 'VES', 'name': 'Bolívar', 'symbol': 'Bs. '},
    {'code': 'COP', 'name': 'Peso Colombiano', 'symbol': '\$'},
  ];

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
    'DIC',
  ];

  final List<Map<String, dynamic>> members = [
    {
      'id': 'local-demo-1',
      'name': 'Cliente Demo',
      'cedula': '12345678',
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
      'assignedRoutine': '',
      'assignedRoutineId': ''
    },
  ];

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

  final List<Map<String, String>> activities = [
    {'type': 'SISTEMA', 'name': 'App iniciada', 'time': 'Ahora'},
  ];

  final List<Map<String, dynamic>> routines = [
    {
      'id': 'r1',
      'name': 'Full Body Principiante',
      'level': 'Principiante',
      'duration': 45,
      'exercises': 8,
      'assigned': 0,
      'equipment': 'Sin equipamiento'
    },
    {
      'id': 'r2',
      'name': 'Hypertrophy Matrix',
      'level': 'Avanzado',
      'duration': 60,
      'exercises': 12,
      'assigned': 0,
      'equipment': 'Con pesas'
    },
    {
      'id': 'r3',
      'name': 'Push Pull Legs',
      'level': 'Intermedio',
      'duration': 55,
      'exercises': 9,
      'assigned': 0,
      'equipment': 'Con pesas'
    },
    {
      'id': 'r4',
      'name': 'HIIT Cardio Blast',
      'level': 'Intermedio',
      'duration': 30,
      'exercises': 6,
      'assigned': 0,
      'equipment': 'Sin equipamiento'
    },
    {
      'id': 'r5',
      'name': 'Fuerza Máxima',
      'level': 'Avanzado',
      'duration': 75,
      'exercises': 10,
      'assigned': 0,
      'equipment': 'Con barra'
    },
  ];

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

  final List<Map<String, dynamic>> classTypes = [
    {'id': 'ct1', 'name': 'YOGA', 'color': 0xFFFF1744, 'icon': 0xe4a4},
    {'id': 'ct2', 'name': 'SPINNING', 'color': 0xFFFF1744, 'icon': 0xe4a7},
    {'id': 'ct3', 'name': 'CROSSFIT', 'color': 0xFFFF1744, 'icon': 0xe4a8},
    {'id': 'ct4', 'name': 'BOXEO', 'color': 0xFFFF1744, 'icon': 0xe4a9},
    {'id': 'ct5', 'name': 'PILATES', 'color': 0xFFFF1744, 'icon': 0xe4aa},
  ];

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

  double get occupancy {
    if (capacity == 0) return 0;
    return inside / capacity;
  }

  List<Map<String, dynamic>> get filteredTransactions {
    if (transactionFilter == 'INGRESOS') {
      return transactions.where((t) => t['type'] == 'INGRESO').toList();
    }
    if (transactionFilter == 'EGRESOS') {
      return transactions.where((t) => t['type'] == 'EGRESO').toList();
    }
    return transactions;
  }

  void _goToSection(int newSection) {
    if (newSection == _section) return;
    _sectionHistory.add(_section);
    setState(() => _section = newSection);
  }

  void _goBackInApp() {
    if (_sectionHistory.isNotEmpty) {
      final prev = _sectionHistory.removeLast();
      setState(() => _section = prev);
    } else if (_section != 0) {
      setState(() => _section = 0);
    }
  }

  List<Map<String, dynamic>> activeAlerts(BuildContext context) {
    final alerts = <Map<String, dynamic>>[];
    for (final m in members) {
      if (m['status'].toString().toUpperCase() == 'PENDIENTE') {
        final id = 'pendiente-${m['id']}';
        if (dismissedAlerts.contains(id)) continue;
        alerts.add({
          'id': id,
          'type': 'PENDIENTE',
          'title': '${m['name']}',
          'subtitle': 'Nuevo registro · Esperando aprobación',
          'color': context.colors.red,
          'icon': Icons.person_add_alt_1_rounded,
          'member': m,
          'action': 'approve_client',
        });
      }
    }
    for (final m in members) {
      if (m['status'].toString().toUpperCase() == 'VENCIDO') {
        final id = 'vencida-${m['id']}';
        if (dismissedAlerts.contains(id)) continue;
        alerts.add({
          'id': id,
          'type': 'VENCIDA',
          'title': '${m['name']}',
          'subtitle': 'Membresía vencida · Plan ${m['plan']}',
          'color': context.colors.red,
          'icon': Icons.block_rounded,
          'member': m,
          'action': 'client_detail',
        });
      }
    }
    for (final m in members) {
      if (m['status'].toString().toUpperCase() == 'POR VENCER') {
        final id = 'porvencer-${m['id']}';
        if (dismissedAlerts.contains(id)) continue;
        alerts.add({
          'id': id,
          'type': 'POR VENCER',
          'title': '${m['name']}',
          'subtitle': 'Vence pronto · Plan ${m['plan']}',
          'color': context.colors.yellow,
          'icon': Icons.warning_amber_rounded,
          'member': m,
          'action': 'client_detail',
        });
      }
    }
    if (capacity > 0 && inside / capacity >= 0.8) {
      final id = 'aforo-alto';
      if (!dismissedAlerts.contains(id)) {
        alerts.add({
          'id': id,
          'type': 'AFORO',
          'title': 'Aforo alto',
          'subtitle': '$inside/$capacity personas dentro',
          'color': context.colors.blue,
          'icon': Icons.people_alt_rounded,
          'action': 'dashboard',
        });
      }
    }
    return alerts;
  }

  int alertCount(BuildContext context) => activeAlerts(context).length;

  List<Map<String, dynamic>> filteredAlerts(BuildContext context) {
    final all = activeAlerts(context);
    if (alertFilter == 'TODAS') return all;
    if (alertFilter == 'PENDIENTES')
      return all.where((a) => a['type'] == 'PENDIENTE').toList();
    if (alertFilter == 'VENCIDAS')
      return all.where((a) => a['type'] == 'VENCIDA').toList();
    if (alertFilter == 'POR VENCER')
      return all.where((a) => a['type'] == 'POR VENCER').toList();
    if (alertFilter == 'INFO')
      return all.where((a) => a['type'] == 'AFORO').toList();
    return all;
  }

  void dismissAlert(String id) {
    setState(() => dismissedAlerts.add(id));
    _saveLocalData();
  }

  bool get isPinLocked {
    if (pinLockedUntil == null) return false;
    return DateTime.now().isBefore(pinLockedUntil!);
  }

  int get pinLockSecondsLeft {
    if (pinLockedUntil == null) return 0;
    final diff = pinLockedUntil!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  void tryAdminLogin() {
    if (isPinLocked) return;
    if (pinController.text == adminPin) {
      setState(() {
        currentRole = UserRole.admin;
        pinController.clear();
        pinAttempts = 0;
        loginScreen = 'choose';
      });
      _saveLocalData();
    } else {
      pinAttempts++;
      if (pinAttempts >= 3) {
        pinLockedUntil = DateTime.now().add(const Duration(seconds: 60));
        pinAttempts = 0;
        if (mounted) {
          final ctx = context;
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content:
                  const Text('Demasiados intentos. Bloqueado 60 segundos.'),
              backgroundColor: ctx.colors.red,
            ),
          );
        }
      } else {
        if (mounted) {
          final ctx = context;
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text('PIN incorrecto · Intento $pinAttempts de 3'),
              backgroundColor: ctx.colors.red,
            ),
          );
        }
      }
      pinController.clear();
      setState(() {});
    }
  }

  Future<void> tryClientLogin() async {
    final cedula = clientCedulaController.text.trim();
    if (cedula.isEmpty) {
      if (mounted) {
        final ctx = context;
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: const Text('Ingresa tu cédula'),
            backgroundColor: ctx.colors.red,
          ),
        );
      }
      return;
    }
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('members')
          .select()
          .eq('cedula', cedula)
          .maybeSingle();
      if (response == null) {
        if (mounted) {
          final ctx = context;
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: const Text('Cédula no encontrada. Regístrate abajo.'),
              backgroundColor: ctx.colors.red,
            ),
          );
        }
        return;
      }
      final member = {
        'id': response['id'],
        'name': response['name'] ?? '',
        'cedula': response['cedula'] ?? '',
        'phone': response['phone'] ?? '',
        'plan': response['plan'] ?? '',
        'expiry': response['expiry'] ?? '',
        'status': response['status'] ?? 'ACTIVO',
        'memberSince': response['member_since'] ?? '',
        'payments': response['payments'] ?? 0,
        'totalPaid': (response['total_paid'] as num?)?.toDouble() ?? 0.0,
        'attendance': response['attendance'] ?? 0,
        'lastVisit': response['last_visit'] ?? '',
        'qrCode': response['qr_code'] ?? '',
        'assignedRoutine': response['assigned_routine'] ?? '',
        'assignedRoutineId': response['assigned_routine_id'] ?? '',
      };
      if (!mounted) return;
      setState(() {
        loggedClient = member;
        currentRole = UserRole.client;
        clientCedulaController.clear();
        loginScreen = 'choose';
      });
      await _saveLocalData();
      await loadClientAforo();
      await loadClientStreak();
      startAforoAutoRefresh();
    } catch (e) {
      debugPrint('❌ Error login cliente: $e');
      if (mounted) {
        final ctx = context;
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: ctx.colors.red,
          ),
        );
      }
    }
  }

  Future<void> tryClientRegister() async {
    final name = regNameController.text.trim();
    final cedula = regCedulaController.text.trim();
    final phone = regPhoneController.text.trim();
    if (name.isEmpty || cedula.isEmpty) {
      if (mounted) {
        final ctx = context;
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: const Text('Nombre y cédula son obligatorios'),
            backgroundColor: ctx.colors.red,
          ),
        );
      }
      return;
    }
    if (regSelectedPlan.isEmpty) {
      if (mounted) {
        final ctx = context;
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: const Text('Selecciona un plan'),
            backgroundColor: ctx.colors.yellow,
          ),
        );
      }
      return;
    }
    setState(() => regLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final existing = await supabase
          .from('members')
          .select('id')
          .eq('cedula', cedula)
          .maybeSingle();
      if (existing != null) {
        if (mounted) {
          setState(() => regLoading = false);
          final ctx = context;
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: const Text('Ya existe un registro con esa cédula'),
              backgroundColor: ctx.colors.yellow,
            ),
          );
        }
        return;
      }
      final now = DateTime.now();
      final qrCode = 'SYNTH-CLIENT-${now.millisecondsSinceEpoch}';
      final newMember = {
        'name': name,
        'cedula': cedula,
        'phone': phone.isEmpty ? '+00 000 000000' : phone,
        'plan': regSelectedPlan,
        'expiry': 'Pendiente',
        'status': 'PENDIENTE',
        'member_since': _formatMemberSince(now),
        'payments': 0,
        'total_paid': 0,
        'attendance': 0,
        'last_visit': 'Sin registro',
        'qr_code': qrCode,
      };
      try {
        await supabase.from('members').insert(newMember);
      } catch (e) {
        debugPrint('⚠️ Error insertando miembro: $e');
      }
      setState(() {
        members.insert(0, {
          'id': 'local-${now.millisecondsSinceEpoch}',
          'name': name,
          'cedula': cedula,
          'phone': phone.isEmpty ? '+00 000 000000' : phone,
          'plan': regSelectedPlan,
          'expiry': 'Pendiente',
          'status': 'PENDIENTE',
          'memberSince': _formatMemberSince(now),
          'payments': 0,
          'totalPaid': 0.0,
          'attendance': 0,
          'lastVisit': 'Sin registro',
          'qrCode': qrCode,
          'assignedRoutine': '',
          'assignedRoutineId': '',
        });
        regLoading = false;
        regNameController.clear();
        regCedulaController.clear();
        regPhoneController.clear();
        regSelectedPlan = '';
        loginScreen = 'registered';
      });
      addActivity('NUEVO REGISTRO', name);
      await _saveLocalData();
    } catch (e) {
      debugPrint('❌ Error registro: $e');
      if (mounted) {
        setState(() => regLoading = false);
        final ctx = context;
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: ctx.colors.red,
          ),
        );
      }
    }
  }

  void logout() {
    _aforoTimer?.cancel();
    _sectionHistory.clear();
    setState(() {
      currentRole = UserRole.none;
      loggedClient = null;
      _section = 0;
      loginScreen = 'choose';
      pinController.clear();
      clientCedulaController.clear();
      clientInsideCount = 0;
      clientStreak = 0;
      clientCheckinDates = [];
    });
    _saveLocalData();
  }

  void confirmLogout() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: dialogContext.colors.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: dialogContext.colors.border),
          ),
          title: Text(
            'CERRAR SESIÓN',
            style: TextStyle(
              color: dialogContext.colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            '¿Seguro que deseas cerrar sesión?',
            style: TextStyle(color: dialogContext.colors.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'CANCELAR',
                style: TextStyle(color: dialogContext.colors.muted),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                logout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: dialogContext.colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'CERRAR',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> openGymWhatsApp({String? clientName, String? customText}) async {
    final cleanPhone = gymPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final text = customText ??
        (clientName != null && clientName.isNotEmpty
            ? 'Hola, soy $clientName. Quiero consultar sobre mi membresía en SYNTHETIX GYM.'
            : 'Hola, quiero consultar sobre SYNTHETIX GYM.');
    final url = 'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(text)}';
    try {
      final uri = Uri.parse(url);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        final ctx = context;
        await Clipboard.setData(ClipboardData(text: url));
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('Enlace copiado: $url'),
            backgroundColor: ctx.colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final ctx = context;
        await Clipboard.setData(ClipboardData(text: url));
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('Enlace copiado: $url'),
            backgroundColor: ctx.colors.green,
          ),
        );
      }
    }
  }

  Future<void> requestRenewal() async {
    final client = loggedClient;
    if (client == null) return;
    final name = client['name'].toString();
    final plan = client['plan'].toString();
    final expiry = client['expiry'].toString();
    final cedula = client['cedula'].toString();
    final customText =
        '🔄 SOLICITUD DE RENOVACIÓN\n\n👤 Cliente: $name\n🆔 Cédula: $cedula\n📋 Plan: $plan\n📅 Vence: $expiry\n\nQuiero renovar mi membresía.';
    await openGymWhatsApp(clientName: name, customText: customText);
    final notifId =
        'renewal-${client['id']}-${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      renewalRequests.insert(0, {
        'id': notifId,
        'memberId': client['id'],
        'name': name,
        'cedula': cedula,
        'plan': plan,
        'expiry': expiry,
        'createdAt': DateTime.now().toIso8601String(),
        'read': false,
      });
    });
    addActivity('RENOVACIÓN', '$name solicitó renovación');
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('activities').insert({
        'type': 'RENOVACIÓN',
        'name': '$name solicitó renovación',
      });
    } catch (e) {
      debugPrint('⚠️ Error enviando notif renovación: $e');
    }
    await _saveLocalData();
    if (!mounted) return;
    final ctx = context;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content:
            const Text('✅ Solicitud enviada. El gym recibió tu notificación.'),
        backgroundColor: ctx.colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> loadClientAforo() async {
    if (loggedClient == null) return;
    try {
      if (mounted) setState(() => clientLoadingAforo = true);
      final supabase = Supabase.instance.client;
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final startOfDayStr = startOfDay.toIso8601String();
      final response = await supabase
          .from('checkins')
          .select()
          .gte('created_at', startOfDayStr)
          .order('created_at', ascending: true);
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
        clientInsideCount = finalInside;
        clientCapacity = capacity;
        clientLoadingAforo = false;
      });
    } catch (e) {
      debugPrint('❌ Error cargando aforo cliente: $e');
      if (mounted) setState(() => clientLoadingAforo = false);
    }
  }

  void startAforoAutoRefresh() {
    _aforoTimer?.cancel();
    _aforoTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (currentRole == UserRole.client && loggedClient != null) {
        loadClientAforo();
      } else {
        timer.cancel();
      }
    });
  }

  void stopAforoAutoRefresh() {
    _aforoTimer?.cancel();
    _aforoTimer = null;
  }

  Future<void> loadClientStreak() async {
    if (loggedClient == null) return;
    try {
      final supabase = Supabase.instance.client;
      final memberId = loggedClient!['id'];
      final sixtyDaysAgo = DateTime.now().subtract(const Duration(days: 60));
      final sixtyDaysAgoStr = sixtyDaysAgo.toIso8601String();
      final response = await supabase
          .from('checkins')
          .select()
          .eq('member_id', memberId)
          .eq('type', 'ENTRADA')
          .gte('created_at', sixtyDaysAgoStr)
          .order('created_at', ascending: false);
      final Set<String> uniqueDays = {};
      for (final row in response) {
        final d =
            DateTime.tryParse(row['created_at'].toString()) ?? DateTime.now();
        final key =
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        uniqueDays.add(key);
      }
      final sortedDays = uniqueDays.toList()..sort((a, b) => b.compareTo(a));
      int streak = 0;
      DateTime cursor = DateTime.now();
      cursor = DateTime(cursor.year, cursor.month, cursor.day);
      for (int i = 0; i < 60; i++) {
        final key =
            '${cursor.year}-${cursor.month.toString().padLeft(2, '0')}-${cursor.day.toString().padLeft(2, '0')}';
        if (sortedDays.contains(key)) {
          streak++;
        } else if (i == 0) {
          // permite racha viva
        } else {
          break;
        }
        cursor = cursor.subtract(const Duration(days: 1));
      }
      if (!mounted) return;
      setState(() {
        clientStreak = streak;
        clientCheckinDates = sortedDays;
      });
    } catch (e) {
      debugPrint('❌ Error cargando racha: $e');
    }
  }

  Future<void> _processGymQrScan(String scannedCode) async {
    if (_qrProcessing) return;
    if (loggedClient == null) return;
    _qrProcessing = true;
    final client = loggedClient!;
    final memberId = client['id'];
    final memberName = client['name'].toString();
    final status = client['status'].toString().toUpperCase();
    final isValid = scannedCode.startsWith('SYNTH-GYM-');
    if (!isValid) {
      _qrProcessing = false;
      if (!mounted) return;
      await _showAccessOverlay(
        success: false,
        title: 'QR INVÁLIDO',
        subtitle: 'Este código no pertenece al gimnasio.',
        name: memberName,
        status: 'INVÁLIDO',
      );
      return;
    }
    String type = 'ENTRADA';
    try {
      final supabase = Supabase.instance.client;
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final startOfDayStr = startOfDay.toIso8601String();
      final todayCheckins = await supabase
          .from('checkins')
          .select()
          .eq('member_id', memberId)
          .gte('created_at', startOfDayStr)
          .order('created_at', ascending: true);
      final lastType = todayCheckins.isNotEmpty
          ? todayCheckins.last['type'].toString().toUpperCase()
          : '';
      type = lastType == 'ENTRADA' ? 'SALIDA' : 'ENTRADA';
      final isBlocked = status != 'ACTIVO';
      await supabase.from('checkins').insert({
        'member_id': memberId,
        'type': type,
        'authorized': !isBlocked,
        'reason': isBlocked ? 'Membresía $status' : null,
        'registered_by': 'client_qr',
      });
      await supabase.from('activities').insert({
        'type': isBlocked ? 'BLOQUEADO' : type,
        'name': memberName,
      });
      if (type == 'ENTRADA' && !isBlocked) {
        final attendance = (client['attendance'] as num?)?.toInt() ?? 0;
        await supabase.from('members').update({
          'attendance': attendance + 1,
          'last_visit': _formatDate(DateTime.now()),
        }).eq('id', memberId);
        if (mounted) {
          setState(() {
            loggedClient!['attendance'] = attendance + 1;
            loggedClient!['lastVisit'] = _formatDate(DateTime.now());
            inside++;
            clientInsideCount++;
          });
          await loadClientStreak();
        }
      } else if (type == 'SALIDA') {
        if (mounted) {
          setState(() {
            if (clientInsideCount > 0) clientInsideCount--;
          });
        }
      }
      if (mounted) addActivity(isBlocked ? 'BLOQUEADO' : type, memberName);
      await loadActivities();
      await loadCheckins();
      await loadClientAforo();
      await _saveLocalData();
      if (!mounted) return;
      await _showAccessOverlay(
        success: !isBlocked,
        title: isBlocked ? 'ACCESO DENEGADO' : 'ACCESO PERMITIDO',
        subtitle: isBlocked
            ? 'Membresía $status. Contacta al gym.'
            : type == 'ENTRADA'
                ? '¡Bienvenido al gimnasio!'
                : '¡Hasta pronto!',
        name: memberName,
        status: status,
        type: type,
      );
    } catch (e) {
      debugPrint('❌ Error procesando QR: $e');
      if (mounted) {
        await _showAccessOverlay(
          success: false,
          title: 'ERROR DE CONEXIÓN',
          subtitle: 'No se pudo registrar. Intenta de nuevo.',
          name: memberName,
          status: 'ERROR',
        );
      }
    } finally {
      _qrProcessing = false;
    }
  }

  Future<dynamic> _showAccessOverlay({
    required bool success,
    required String title,
    required String subtitle,
    required String name,
    required String status,
    String? type,
  }) async {
    if (!mounted) return null;
    final color = success ? context.colors.green : context.colors.red;
    final icon = success ? Icons.check_circle_rounded : Icons.cancel_rounded;
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'AccessOverlay',
      barrierColor: Colors.black.withValues(alpha: .85),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (dialogContext, animation, _, __) {
        final scale = Tween<double>(begin: 0.7, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: scale,
            child: Center(
              child: GestureDetector(
                onTap: () => Navigator.pop(dialogContext),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: dialogContext.colors.panel,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: color, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: .45),
                        blurRadius: 60,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: .15),
                          border: Border.all(color: color, width: 4),
                        ),
                        child: Icon(icon, color: color, size: 64),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: color,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: dialogContext.colors.panel2,
                          borderRadius: BorderRadius.circular(18),
                          border:
                              Border.all(color: dialogContext.colors.border),
                        ),
                        child: Column(
                          children: [
                            Text(
                              name.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: dialogContext.colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: .15),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                    color: color.withValues(alpha: .5)),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              subtitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: dialogContext.colors.muted,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: dialogContext.colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                            if (type != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                type == 'ENTRADA'
                                    ? '↑ ENTRADA REGISTRADA'
                                    : '↓ SALIDA REGISTRADA',
                                style: TextStyle(
                                  color: dialogContext.colors.muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Toca para cerrar',
                        style: TextStyle(
                          color: dialogContext.colors.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> openClientQrScanner() async {
    if (loggedClient == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          height: MediaQuery.of(sheetContext).size.height * 0.85,
          decoration: BoxDecoration(
            color: sheetContext.colors.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: sheetContext.colors.muted.withValues(alpha: .4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.qr_code_scanner_rounded,
                        color: sheetContext.colors.red, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'ESCANEAR ACCESO',
                        style: TextStyle(
                          color: sheetContext.colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: Icon(Icons.close_rounded,
                          color: sheetContext.colors.muted),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: MobileScanner(
                    onDetect: (capture) async {
                      final barcodes = capture.barcodes;
                      if (barcodes.isEmpty) return;
                      final code = barcodes.first.rawValue;
                      if (code == null || code.isEmpty) return;
                      Navigator.pop(sheetContext);
                      await _processGymQrScan(code);
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Apunta al QR del gimnasio para registrar tu acceso',
                  style: TextStyle(
                    color: sheetContext.colors.muted,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

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
      await prefs.setString('classTypes', jsonEncode(classTypes));
      await prefs.setString('renewalRequests', jsonEncode(renewalRequests));
      await prefs.setInt('inside', inside);
      await prefs.setStringList('dismissedAlerts', dismissedAlerts.toList());
      await prefs.setString('dismissedDate', dismissedDate);
      await prefs.setString('adminPin', adminPin);
      await prefs.setString('gymPhone', gymPhone);
      await prefs.setString('selectedCurrency', selectedCurrency);
      await prefs.setBool('showConversion', showConversion);
      await prefs.setDouble('usdToVes', usdToVes);
      await prefs.setDouble('eurToVes', eurToVes);
      await prefs.setDouble('copToVes', copToVes);
      await prefs.setString('qrMode', qrMode);
      await prefs.setInt('capacity', capacity);
    } catch (e) {
      debugPrint('❌ Error guardando local: $e');
    }
  }

  Future<void> _loadLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedAdminPin = prefs.getString('adminPin');
      adminPin =
          (savedAdminPin != null && RegExp(r'^\d{4}$').hasMatch(savedAdminPin))
              ? savedAdminPin
              : '1234';
      if (savedAdminPin != adminPin) {
        await prefs.setString('adminPin', adminPin);
      }
      final savedGymPhone = prefs.getString('gymPhone');
      if (savedGymPhone != null && savedGymPhone.isNotEmpty) {
        gymPhone = savedGymPhone;
      }
      final savedCurrency = prefs.getString('selectedCurrency');
      if (savedCurrency != null) selectedCurrency = savedCurrency;
      final savedConversion = prefs.getBool('showConversion');
      if (savedConversion != null) showConversion = savedConversion;
      final savedUsd = prefs.getDouble('usdToVes');
      if (savedUsd != null && savedUsd > 0) usdToVes = savedUsd;
      final savedEur = prefs.getDouble('eurToVes');
      if (savedEur != null && savedEur > 0) eurToVes = savedEur;
      final savedCop = prefs.getDouble('copToVes');
      if (savedCop != null && savedCop > 0) copToVes = savedCop;
      final savedQrMode = prefs.getString('qrMode');
      if (savedQrMode != null) qrMode = savedQrMode;
      final savedCapacity = prefs.getInt('capacity');
      if (savedCapacity != null && savedCapacity > 0) capacity = savedCapacity;
      final todayKey = _formatDateForCode(DateTime.now());
      final savedDismissedDate = prefs.getString('dismissedDate') ?? '';
      if (savedDismissedDate != todayKey) {
        await prefs.setStringList('dismissedAlerts', []);
        await prefs.setString('dismissedDate', todayKey);
        dismissedAlerts = {};
        dismissedDate = todayKey;
      } else {
        final saved = prefs.getStringList('dismissedAlerts') ?? [];
        dismissedAlerts = saved.toSet();
        dismissedDate = savedDismissedDate;
      }
      final membersStr = prefs.getString('members');
      final plansStr = prefs.getString('plans');
      final transactionsStr = prefs.getString('transactions');
      final activitiesStr = prefs.getString('activities');
      final routinesStr = prefs.getString('routines');
      final exercisesStr = prefs.getString('exercises');
      final trainersStr = prefs.getString('trainers');
      final classesStr = prefs.getString('classes');
      final classTypesStr = prefs.getString('classTypes');
      final renewalStr = prefs.getString('renewalRequests');
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
        if (loaded.isNotEmpty) transactions = loaded;
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
      if (classTypesStr != null) {
        final loaded = (jsonDecode(classTypesStr) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (loaded.isNotEmpty) {
          classTypes.clear();
          classTypes.addAll(loaded);
        }
      }
      if (renewalStr != null) {
        final loaded = (jsonDecode(renewalStr) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (loaded.isNotEmpty) {
          renewalRequests = loaded;
        }
      }
      if (savedInside != null) inside = savedInside;
    } catch (e) {
      debugPrint('❌ Error cargando local: $e');
    }
  }

  Future<void> loadMembers() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('members')
          .select()
          .order('created_at', ascending: false);
      if (response.isNotEmpty) {
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
            'assignedRoutine': row['assigned_routine'] ?? '',
            'assignedRoutineId': row['assigned_routine_id'] ?? '',
          });
        }
        if (!mounted) return;
        setState(() {
          members.clear();
          members.addAll(loaded);
          activeMembers = members.length;
        });
        await _saveLocalData();
      }
    } catch (e) {
      debugPrint('❌ Error loading members: $e');
    }
  }

  Future<void> loadPayments() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('payments')
          .select(
              'id, member_id, amount, method, status, created_at, members(name, plan)')
          .order('created_at', ascending: false);
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
      final loadedTopPlans = <Map<String, dynamic>>[];
      for (int i = 0; i < sortedPlans.length && i < 4; i++) {
        final e = sortedPlans[i];
        loadedTopPlans.add({
          'name': e.key.replaceFirst('Plan ', ''),
          'sales': e.value['sales'],
          'revenue': e.value['revenue'],
          'colorIndex': i,
        });
      }
      double totalIngresos = 0;
      for (final t in loaded) {
        totalIngresos += (t['amount'] as num).toDouble();
      }
      if (!mounted) return;
      if (loaded.isNotEmpty) {
        setState(() {
          transactions = loaded;
          monthlyIncome = calcMonthly;
          paymentMethods = calcMethods;
          weeklyIncome = calcWeekly;
          weeklyExpense = [0, 0, 0, 0];
          topPlans = loadedTopPlans;
          income = totalIngresos;
        });
        await _saveLocalData();
      }
    } catch (e) {
      debugPrint('❌ Error loading payments: $e');
    }
  }

  Future<void> loadPlans() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('plans')
          .select()
          .order('created_at', ascending: true);
      if (response.isNotEmpty) {
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
        await _saveLocalData();
      }
    } catch (e) {
      debugPrint('❌ Error loading plans: $e');
    }
  }

  Future<void> loadActivities() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('activities')
          .select()
          .order('created_at', ascending: false)
          .limit(20);
      if (response.isNotEmpty) {
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
      debugPrint('❌ Error loading activities: $e');
    }
  }

  Future<void> loadCheckins() async {
    try {
      if (mounted) setState(() => loadingCheckins = true);
      final supabase = Supabase.instance.client;
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final startOfDayStr = startOfDay.toIso8601String();
      final response = await supabase
          .from('checkins')
          .select()
          .gte('created_at', startOfDayStr)
          .order('created_at', ascending: true);
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
    } catch (e) {
      debugPrint('❌ Error cargando checkins: $e');
      if (mounted) setState(() => loadingCheckins = false);
    }
  }

  Future<void> loadAllData() async {
    await _loadLocalData();
    if (mounted) setState(() => loadingData = false);
    _syncWithSupabase();
  }

  Future<void> _syncWithSupabase() async {
    try {
      Supabase.instance.client;
    } catch (_) {
      try {
        await Supabase.initialize(
          url: SupabaseConfig.supabaseUrl,
          anonKey: SupabaseConfig.supabaseAnonKey,
        );
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        debugPrint('⚠️ Sin conexión a Supabase. Modo offline.');
        return;
      }
    }
    bool ready = false;
    for (int i = 0; i < 30; i++) {
      try {
        Supabase.instance.client;
        ready = true;
        break;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    if (!ready) return;
    try {
      await loadPlans();
    } catch (_) {}
    try {
      await loadMembers();
    } catch (_) {}
    try {
      await loadPayments();
    } catch (_) {}
    try {
      await loadActivities();
    } catch (_) {}
    try {
      await loadCheckins();
    } catch (_) {}
    await _saveLocalData();
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
      'DIC',
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
    if (!mounted) return;
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    setState(() {
      activities.insert(0, {
        'type': type,
        'name': name,
        'time': time,
      });
      if (activities.length > 20) activities.removeLast();
    });
  }

  IconData _iconFromCodePoint(int codePoint) {
    switch (codePoint) {
      case 0xe4a4:
        return Icons.self_improvement;
      case 0xe4a7:
        return Icons.directions_bike;
      case 0xe4a8:
        return Icons.fitness_center;
      case 0xe4a9:
        return Icons.sports_mma;
      case 0xe4aa:
        return Icons.accessibility_new;
      case 0xe4ab:
        return Icons.sports_gymnastics;
      case 0xe4ac:
        return Icons.sports_martial_arts;
      case 0xe4ad:
        return Icons.sports_handball;
      default:
        return Icons.fitness_center;
    }
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
    if (diff.inDays > 0) return 'Expira en ${diff.inDays} dia(s)';
    if (diff.inHours > 0) return 'Expira en ${diff.inHours} hora(s)';
    return 'Expira en ${diff.inMinutes} minuto(s)';
  }

  Future<void> resetAforo() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: dialogContext.colors.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: dialogContext.colors.border),
          ),
          title: Text(
            'RESET AFORO',
            style: TextStyle(
              color: dialogContext.colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'Esto reiniciará el contador a 0. Úsalo si alguien no marcó salida.',
            style: TextStyle(color: dialogContext.colors.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'CANCELAR',
                style: TextStyle(color: dialogContext.colors.muted),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: dialogContext.colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'RESET',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;
    setState(() {
      inside = 0;
      clientInsideCount = 0;
    });
    addActivity('RESET AFORO', 'Contador reiniciado');
    await _saveLocalData();
    if (!mounted) return;
    final ctx = context;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: const Text('🔄 Aforo reiniciado a 0'),
        backgroundColor: ctx.colors.green,
      ),
    );
  }

  Future<void> downloadQrAsPng() async {
    try {
      final Uint8List? imageBytes = await _qrScreenshotController.capture();
      if (imageBytes == null) return;
      await Clipboard.setData(ClipboardData(text: qrToken));
      if (mounted) {
        final ctx = context;
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('QR token copiado: $qrToken'),
            backgroundColor: ctx.colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> shareQrPng() async {
    try {
      final Uint8List? imageBytes = await _qrScreenshotController.capture();
      if (imageBytes == null) return;
      if (kIsWeb) {
        final text = 'Accede con este QR: $qrToken\nVálido: $qrTimeLeft';
        await Clipboard.setData(ClipboardData(text: text));
        if (mounted) {
          final ctx = context;
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text('QR copiado: $qrToken'),
              backgroundColor: ctx.colors.blue,
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
        text: 'QR de acceso SYNTHETIX GYM\n$qrToken\n$qrTimeLeft',
        subject: 'Acceso QR - SYNTHETIX GYM',
      );
    } catch (e) {
      debugPrint('Error: $e');
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
          final ctx = context;
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text('Plan "$name" copiado.'),
              backgroundColor: ctx.colors.blue,
            ),
          );
        }
        return;
      }
      await Share.share(text, subject: 'Plan $name - SYNTHETIX GYM');
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> approveClient(Map<String, dynamic> member) async {
    final memberId = member['id'];
    if (memberId == null) return;
    final plan = member['plan'].toString();
    final now = DateTime.now();
    final expiryDate = _calculateExpiryDate(plan, now);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final ctx = context;
    setState(() {
      for (var m in members) {
        if (m['id'] == memberId) {
          m['status'] = 'ACTIVO';
          m['expiry'] = expiryDate;
          break;
        }
      }
      dismissedAlerts.remove('pendiente-$memberId');
    });
    addActivity('APROBADO', member['name'].toString());
    await _saveLocalData();
    messenger.showSnackBar(
      SnackBar(
        content: Text('${member['name']} aprobado como ACTIVO'),
        backgroundColor: ctx.colors.green,
      ),
    );
    if (memberId.toString().startsWith('local-')) return;
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('members').update({
        'status': 'ACTIVO',
        'expiry': expiryDate,
      }).eq('id', memberId);
      await supabase.from('activities').insert({
        'type': 'APROBADO',
        'name': member['name'].toString(),
      });
      await loadMembers();
      await loadActivities();
      await _saveLocalData();
    } catch (e) {
      debugPrint('⚠️ Aprobación solo local: $e');
    }
  }

  Future<void> assignRoutineToMember(
      Map<String, dynamic> routine, Map<String, dynamic> member) async {
    final routineName = routine['name'].toString();
    final routineId = routine['id'].toString();
    final memberId = member['id'];
    final memberName = member['name'].toString();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final ctx = context;
    try {
      final supabase = Supabase.instance.client;
      if (memberId != null && !memberId.toString().startsWith('local-')) {
        try {
          await supabase.from('members').update({
            'assigned_routine': routineName,
            'assigned_routine_id': routineId,
          }).eq('id', memberId);
        } catch (e) {
          debugPrint('⚠️ Error asignando: $e');
        }
      }
      setState(() {
        for (var m in members) {
          if (m['id'] == memberId) {
            m['assignedRoutine'] = routineName;
            m['assignedRoutineId'] = routineId;
            break;
          }
        }
        int count = 0;
        for (var m in members) {
          if (m['assignedRoutineId'] == routineId) count++;
        }
        routine['assigned'] = count;
      });
      addActivity('RUTINA ASIGNADA', '$routineName → $memberName');
      await _saveLocalData();
      await loadMembers();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('✅ Rutina asignada a $memberName'),
          backgroundColor: ctx.colors.green,
        ),
      );
    } catch (e) {
      debugPrint('❌ Error asignando rutina: $e');
    }
  }

  List<Map<String, dynamic>> _classesToday() {
    final now = DateTime.now();
    final dayNames = [
      'LUNES',
      'MARTES',
      'MIÉRCOLES',
      'JUEVES',
      'VIERNES',
      'SÁBADO',
      'DOMINGO'
    ];
    final today = dayNames[(now.weekday - 1).clamp(0, 6)];
    return classes.where((c) => c['day'] == today).toList()
      ..sort((a, b) => a['time'].toString().compareTo(b['time'].toString()));
  }

  void addMember() {
    final name = TextEditingController();
    final phone = TextEditingController();
    final cedula = TextEditingController();
    String plan = plans.isNotEmpty ? plans.first['name'].toString() : '';
    showDialog(
      context: context,
      builder: (dialogContext) {
        return _dialog(
          title: 'NUEVO MIEMBRO',
          child: StatefulBuilder(
            builder: (dialogContext, setDialogState) {
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
                    dropdownColor: dialogContext.colors.panel2,
                    style: TextStyle(color: dialogContext.colors.white),
                    decoration: _inputDecoration(dialogContext, 'Plan'),
                    items: plans.map((p) {
                      final value = p['name'].toString();
                      return DropdownMenuItem<String>(
                          value: value, child: Text(value));
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => plan = value);
                    },
                  ),
                  const SizedBox(height: 24),
                  _button('CREAR MIEMBRO', dialogContext.colors.red, () async {
                    if (name.text.trim().isEmpty) return;
                    if (plan.isEmpty) return;
                    final navigator = Navigator.of(dialogContext);
                    final messenger = ScaffoldMessenger.of(dialogContext);
                    final ctx = dialogContext;
                    final now = DateTime.now();
                    final expiryDate = _calculateExpiryDate(plan, now);
                    final qrCode = 'SYNTH-CLIENT-${now.millisecondsSinceEpoch}';
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
                      'assignedRoutine': '',
                      'assignedRoutineId': '',
                    };
                    setState(() {
                      members.insert(0, localMember);
                      activeMembers = members.length;
                    });
                    addActivity('NUEVO MIEMBRO', name.text.trim());
                    navigator.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        content: const Text('Miembro creado correctamente'),
                        backgroundColor: ctx.colors.green,
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
                  }),
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
    final cedula = TextEditingController(text: member['cedula'].toString());
    final expiry = TextEditingController(text: member['expiry'].toString());
    String plan = member['plan'].toString();
    String status = member['status'].toString();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return _dialog(
          title: 'EDITAR MIEMBRO',
          accent: dialogContext.colors.yellow,
          child: StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(name, 'Nombre completo'),
                  const SizedBox(height: 12),
                  _field(phone, 'Teléfono'),
                  const SizedBox(height: 12),
                  _field(cedula, 'Cédula'),
                  const SizedBox(height: 12),
                  _field(expiry, 'Vencimiento (ej: 30 NOV 2026)'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: plan,
                    dropdownColor: dialogContext.colors.panel2,
                    style: TextStyle(color: dialogContext.colors.white),
                    decoration: _inputDecoration(dialogContext, 'Plan'),
                    items: plans.map((p) {
                      final value = p['name'].toString();
                      return DropdownMenuItem<String>(
                          value: value, child: Text(value));
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => plan = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: status,
                    dropdownColor: dialogContext.colors.panel2,
                    style: TextStyle(color: dialogContext.colors.white),
                    decoration: _inputDecoration(dialogContext, 'Estado'),
                    items: const [
                      DropdownMenuItem(value: 'ACTIVO', child: Text('ACTIVO')),
                      DropdownMenuItem(
                          value: 'POR VENCER', child: Text('POR VENCER')),
                      DropdownMenuItem(
                          value: 'VENCIDO', child: Text('VENCIDO')),
                      DropdownMenuItem(
                          value: 'PENDIENTE', child: Text('PENDIENTE')),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => status = value);
                    },
                  ),
                  const SizedBox(height: 24),
                  _button('GUARDAR CAMBIOS', dialogContext.colors.yellow,
                      () async {
                    if (name.text.trim().isEmpty) return;
                    final navigator = Navigator.of(dialogContext);
                    final messenger = ScaffoldMessenger.of(dialogContext);
                    final ctx = dialogContext;
                    setState(() {
                      member['name'] = name.text.trim();
                      member['phone'] = phone.text.trim();
                      member['cedula'] = cedula.text.trim();
                      member['expiry'] = expiry.text.trim();
                      member['plan'] = plan;
                      member['status'] = status;
                    });
                    addActivity('EDITADO', name.text.trim());
                    navigator.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        content:
                            const Text('Miembro actualizado correctamente'),
                        backgroundColor: ctx.colors.green,
                      ),
                    );
                    await _saveLocalData();
                    final memberId = member['id'];
                    if (memberId == null ||
                        memberId.toString().startsWith('local-')) return;
                    try {
                      final supabase = Supabase.instance.client;
                      await supabase.from('members').update({
                        'name': name.text.trim(),
                        'phone': phone.text.trim(),
                        'cedula': cedula.text.trim(),
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
                  }, darkText: true),
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
      builder: (dialogContext) {
        return _dialog(
          title: 'ELIMINAR MIEMBRO',
          accent: dialogContext.colors.red,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: dialogContext.colors.red, size: 60),
              const SizedBox(height: 18),
              Text(
                '¿Eliminar a ${member['name']}?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: dialogContext.colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Esta acción no se puede deshacer.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: dialogContext.colors.muted, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: BorderSide(color: dialogContext.colors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13)),
                      ),
                      child: Text('CANCELAR',
                          style: TextStyle(
                              color: dialogContext.colors.white,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final navigator = Navigator.of(dialogContext);
                        final messenger = ScaffoldMessenger.of(dialogContext);
                        final ctx = dialogContext;
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
                            backgroundColor: ctx.colors.green,
                          ),
                        );
                        await _saveLocalData();
                        if (memberId == null ||
                            memberId.toString().startsWith('local-')) return;
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
                        backgroundColor: dialogContext.colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13)),
                      ),
                      child: const Text('ELIMINAR',
                          style: TextStyle(fontWeight: FontWeight.w900)),
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

  void newPayment() {
    if (members.isEmpty) {
      final ctx = context;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: const Text('No hay miembros registrados'),
          backgroundColor: ctx.colors.red,
        ),
      );
      return;
    }
    final amount = TextEditingController();
    String memberName = members.first['name'].toString();
    String method = 'EFECTIVO';
    showDialog(
      context: context,
      builder: (dialogContext) {
        return _dialog(
          title: 'NUEVO PAGO',
          child: StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: memberName,
                    dropdownColor: dialogContext.colors.panel2,
                    style: TextStyle(color: dialogContext.colors.white),
                    decoration: _inputDecoration(dialogContext, 'Miembro'),
                    items: members.map((m) {
                      final value = m['name'].toString();
                      return DropdownMenuItem<String>(
                          value: value, child: Text(value));
                    }).toList(),
                    onChanged: (value) {
                      if (value != null)
                        setDialogState(() => memberName = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  _field(amount, 'Importe', keyboard: TextInputType.number),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: method,
                    dropdownColor: dialogContext.colors.panel2,
                    style: TextStyle(color: dialogContext.colors.white),
                    decoration:
                        _inputDecoration(dialogContext, 'Método de pago'),
                    items: const [
                      DropdownMenuItem(
                          value: 'EFECTIVO', child: Text('EFECTIVO')),
                      DropdownMenuItem(
                          value: 'TARJETA', child: Text('TARJETA')),
                      DropdownMenuItem(
                          value: 'TRANSFERENCIA', child: Text('TRANSFERENCIA')),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => method = value);
                    },
                  ),
                  const SizedBox(height: 24),
                  _button('REGISTRAR PAGO', dialogContext.colors.yellow,
                      () async {
                    final value =
                        double.tryParse(amount.text.replaceAll(',', '.'));
                    if (value == null || value <= 0) return;
                    final memberData = members.firstWhere(
                      (m) => m['name'].toString() == memberName,
                      orElse: () => <String, dynamic>{},
                    );
                    if (memberData.isEmpty) return;
                    final navigator = Navigator.of(dialogContext);
                    final messenger = ScaffoldMessenger.of(dialogContext);
                    final ctx = dialogContext;
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
                      SnackBar(
                        content: const Text('Pago registrado correctamente'),
                        backgroundColor: ctx.colors.green,
                      ),
                    );
                    await _saveLocalData();
                    final memberId = memberData['id'];
                    if (memberId == null ||
                        memberId.toString().startsWith('local-')) return;
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
                  }, darkText: true),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void addPlan() {
    final name = TextEditingController();
    final price = TextEditingController();
    final days = TextEditingController();
    final access = TextEditingController(text: 'ILIMITADO');
    showDialog(
      context: context,
      builder: (dialogContext) {
        return _dialog(
          title: 'NUEVO PLAN',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(name, 'Nombre del plan'),
              const SizedBox(height: 12),
              _field(price, 'Precio', keyboard: TextInputType.number),
              const SizedBox(height: 12),
              _field(days, 'Días de vigencia', keyboard: TextInputType.number),
              const SizedBox(height: 12),
              _field(access, 'Tipo de acceso'),
              const SizedBox(height: 24),
              _button('CREAR PLAN', dialogContext.colors.red, () async {
                final p = double.tryParse(price.text.replaceAll(',', '.'));
                final d = int.tryParse(days.text);
                if (name.text.trim().isEmpty || p == null || d == null) return;
                final navigator = Navigator.of(dialogContext);
                final messenger = ScaffoldMessenger.of(dialogContext);
                final ctx = dialogContext;
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
                setState(() => plans.add(localPlan));
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: const Text('Plan creado correctamente'),
                    backgroundColor: ctx.colors.green,
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
              }),
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
      builder: (dialogContext) {
        return _dialog(
          title: 'EDITAR PLAN',
          accent: dialogContext.colors.red,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(name, 'Nombre del plan'),
              const SizedBox(height: 12),
              _field(price, 'Precio', keyboard: TextInputType.number),
              const SizedBox(height: 12),
              _field(days, 'Días de vigencia', keyboard: TextInputType.number),
              const SizedBox(height: 12),
              _field(access, 'Tipo de acceso'),
              const SizedBox(height: 24),
              _button('GUARDAR CAMBIOS', dialogContext.colors.red, () async {
                final p = double.tryParse(price.text.replaceAll(',', '.'));
                final d = int.tryParse(days.text);
                if (name.text.trim().isEmpty || p == null || d == null) return;
                final navigator = Navigator.of(dialogContext);
                final messenger = ScaffoldMessenger.of(dialogContext);
                final ctx = dialogContext;
                setState(() {
                  plan['name'] = name.text.trim();
                  plan['price'] = p;
                  plan['days'] = d;
                  plan['access'] = access.text.trim();
                });
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: const Text('Plan actualizado correctamente'),
                    backgroundColor: ctx.colors.green,
                  ),
                );
                await _saveLocalData();
                final planId = plan['id'];
                if (planId == null || planId.toString().startsWith('local-'))
                  return;
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
              }, darkText: true),
            ],
          ),
        );
      },
    );
  }

  void deletePlan(Map<String, dynamic> plan) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return _dialog(
          title: 'ELIMINAR PLAN',
          accent: dialogContext.colors.red,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: dialogContext.colors.red, size: 60),
              const SizedBox(height: 18),
              Text(
                '¿Eliminar el plan "${plan['name']}"?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: dialogContext.colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: BorderSide(color: dialogContext.colors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13)),
                      ),
                      child: Text('CANCELAR',
                          style: TextStyle(
                              color: dialogContext.colors.white,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final navigator = Navigator.of(dialogContext);
                        final messenger = ScaffoldMessenger.of(dialogContext);
                        final ctx = dialogContext;
                        final planId = plan['id'];
                        setState(() => plans.remove(plan));
                        navigator.pop();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Plan "${plan['name']}" eliminado'),
                            backgroundColor: ctx.colors.green,
                          ),
                        );
                        await _saveLocalData();
                        if (planId == null ||
                            planId.toString().startsWith('local-')) return;
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
                        backgroundColor: dialogContext.colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13)),
                      ),
                      child: const Text('ELIMINAR',
                          style: TextStyle(fontWeight: FontWeight.w900)),
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

  void addRoutine() {
    final name = TextEditingController();
    final duration = TextEditingController(text: '45');
    final exercisesCount = TextEditingController(text: '8');
    final equipment = TextEditingController(text: 'Sin equipamiento');
    String level = 'Principiante';
    showDialog(
      context: context,
      builder: (dialogContext) {
        return _dialog(
          title: 'NUEVA RUTINA',
          accent: dialogContext.colors.red,
          child: StatefulBuilder(
            builder: (dialogContext, setDialogState) {
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
                    dropdownColor: dialogContext.colors.panel2,
                    style: TextStyle(color: dialogContext.colors.white),
                    decoration: _inputDecoration(dialogContext, 'Nivel'),
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
                  _button('CREAR RUTINA', dialogContext.colors.red, () async {
                    if (name.text.trim().isEmpty) return;
                    final navigator = Navigator.of(dialogContext);
                    final messenger = ScaffoldMessenger.of(dialogContext);
                    final ctx = dialogContext;
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
                    messenger.showSnackBar(
                      SnackBar(
                        content: const Text('Rutina creada correctamente'),
                        backgroundColor: ctx.colors.green,
                      ),
                    );
                  }),
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
      builder: (dialogContext) {
        return _dialog(
          title: 'EDITAR RUTINA',
          accent: dialogContext.colors.yellow,
          child: StatefulBuilder(
            builder: (dialogContext, setDialogState) {
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
                    dropdownColor: dialogContext.colors.panel2,
                    style: TextStyle(color: dialogContext.colors.white),
                    decoration: _inputDecoration(dialogContext, 'Nivel'),
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
                  _button('GUARDAR CAMBIOS', dialogContext.colors.yellow,
                      () async {
                    if (name.text.trim().isEmpty) return;
                    final navigator = Navigator.of(dialogContext);
                    final messenger = ScaffoldMessenger.of(dialogContext);
                    final ctx = dialogContext;
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
                    messenger.showSnackBar(
                      SnackBar(
                        content: const Text('Rutina actualizada correctamente'),
                        backgroundColor: ctx.colors.green,
                      ),
                    );
                  }, darkText: true),
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
      builder: (dialogContext) {
        return _dialog(
          title: 'ELIMINAR RUTINA',
          accent: dialogContext.colors.red,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: dialogContext.colors.red, size: 60),
              const SizedBox(height: 18),
              Text(
                '¿Eliminar "${routine['name']}"?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: dialogContext.colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: BorderSide(color: dialogContext.colors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13)),
                      ),
                      child: Text('CANCELAR',
                          style: TextStyle(
                              color: dialogContext.colors.white,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final navigator = Navigator.of(dialogContext);
                        final messenger = ScaffoldMessenger.of(dialogContext);
                        final ctx = dialogContext;
                        setState(() => routines.remove(routine));
                        navigator.pop();
                        await _saveLocalData();
                        messenger.showSnackBar(
                          SnackBar(
                            content:
                                Text('Rutina "${routine['name']}" eliminada'),
                            backgroundColor: ctx.colors.green,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: dialogContext.colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13)),
                      ),
                      child: const Text('ELIMINAR',
                          style: TextStyle(fontWeight: FontWeight.w900)),
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

  void showAssignRoutineDialog(Map<String, dynamic> routine) {
    final routineName = routine['name'].toString();
    final routineId = routine['id'].toString();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return _dialog(
          title: 'ASIGNAR RUTINA',
          accent: dialogContext.colors.red,
          child: StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              final activeMembers = members
                  .where(
                      (m) => m['status'].toString().toUpperCase() == 'ACTIVO')
                  .toList();
              final assignedIds = members
                  .where((m) => m['assignedRoutineId'] == routineId)
                  .map((m) => m['id'])
                  .toSet();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: dialogContext.colors.panel2,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: dialogContext.colors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.fitness_center_rounded,
                            color: dialogContext.colors.red, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            routineName,
                            style: TextStyle(
                              color: dialogContext.colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                dialogContext.colors.red.withValues(alpha: .15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${assignedIds.length} asignados',
                            style: TextStyle(
                              color: dialogContext.colors.red,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Toca un cliente para ASIGNAR o QUITAR esta rutina:',
                    style: TextStyle(
                        color: dialogContext.colors.muted, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  if (activeMembers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'No hay clientes activos',
                        style: TextStyle(color: dialogContext.colors.muted),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 350),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: activeMembers.length,
                        itemBuilder: (_, i) {
                          final m = activeMembers[i];
                          final mId = m['id'];
                          final hasIt = assignedIds.contains(mId);
                          final mName = m['name'].toString();
                          final initial =
                              mName.isEmpty ? '?' : mName[0].toUpperCase();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  if (hasIt) {
                                    setState(() {
                                      m['assignedRoutine'] = '';
                                      m['assignedRoutineId'] = '';
                                      int count = 0;
                                      for (var x in members) {
                                        if (x['assignedRoutineId'] == routineId)
                                          count++;
                                      }
                                      routine['assigned'] = count;
                                    });
                                    if (mId != null &&
                                        !mId.toString().startsWith('local-')) {
                                      try {
                                        final supabase =
                                            Supabase.instance.client;
                                        await supabase.from('members').update({
                                          'assigned_routine': null,
                                          'assigned_routine_id': null,
                                        }).eq('id', mId);
                                      } catch (e) {
                                        debugPrint('⚠️ Error quitando: $e');
                                      }
                                    }
                                    addActivity('RUTINA QUITADA',
                                        '$routineName ← $mName');
                                  } else {
                                    setState(() {
                                      m['assignedRoutine'] = routineName;
                                      m['assignedRoutineId'] = routineId;
                                      int count = 0;
                                      for (var x in members) {
                                        if (x['assignedRoutineId'] == routineId)
                                          count++;
                                      }
                                      routine['assigned'] = count;
                                    });
                                    if (mId != null &&
                                        !mId.toString().startsWith('local-')) {
                                      try {
                                        final supabase =
                                            Supabase.instance.client;
                                        await supabase.from('members').update({
                                          'assigned_routine': routineName,
                                          'assigned_routine_id': routineId,
                                        }).eq('id', mId);
                                      } catch (e) {
                                        debugPrint('⚠️ Error asignando: $e');
                                      }
                                    }
                                    addActivity('RUTINA ASIGNADA',
                                        '$routineName → $mName');
                                  }
                                  await _saveLocalData();
                                  setDialogState(() {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: hasIt
                                        ? dialogContext.colors.red
                                            .withValues(alpha: .15)
                                        : dialogContext.colors.panel2,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: hasIt
                                          ? dialogContext.colors.red
                                              .withValues(alpha: .45)
                                          : dialogContext.colors.border,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: dialogContext
                                            .colors.red
                                            .withValues(alpha: .15),
                                        child: Text(
                                          initial,
                                          style: TextStyle(
                                            color: dialogContext.colors.red,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          mName,
                                          style: TextStyle(
                                            color: dialogContext.colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Icon(
                                        hasIt
                                            ? Icons.check_circle_rounded
                                            : Icons.add_circle_outline_rounded,
                                        color: hasIt
                                            ? dialogContext.colors.green
                                            : dialogContext.colors.muted,
                                        size: 22,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 20),
                  _button(
                    'CERRAR',
                    dialogContext.colors.red,
                    () {
                      Navigator.pop(dialogContext);
                      setState(() {});
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

  void addExercise() {
    final name = TextEditingController();
    final sets = TextEditingController(text: '3');
    final reps = TextEditingController(text: '12');
    final weight = TextEditingController(text: '0');
    String muscle = 'Pecho';
    String level = 'Principiante';
    showDialog(
      context: context,
      builder: (dialogContext) {
        return _dialog(
          title: 'NUEVO EJERCICIO',
          accent: dialogContext.colors.red,
          child: StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(name, 'Nombre del ejercicio'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: muscle,
                    dropdownColor: dialogContext.colors.panel2,
                    style: TextStyle(color: dialogContext.colors.white),
                    decoration: _inputDecoration(dialogContext, 'Músculo'),
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
                    dropdownColor: dialogContext.colors.panel2,
                    style: TextStyle(color: dialogContext.colors.white),
                    decoration: _inputDecoration(dialogContext, 'Nivel'),
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
                  _button('CREAR EJERCICIO', dialogContext.colors.red,
                      () async {
                    if (name.text.trim().isEmpty) return;
                    final navigator = Navigator.of(dialogContext);
                    final messenger = ScaffoldMessenger.of(dialogContext);
                    final ctx = dialogContext;
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
                    messenger.showSnackBar(
                      SnackBar(
                        content: const Text('Ejercicio creado correctamente'),
                        backgroundColor: ctx.colors.green,
                      ),
                    );
                  }),
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
      builder: (dialogContext) {
        return _dialog(
          title: 'EDITAR EJERCICIO',
          accent: dialogContext.colors.yellow,
          child: StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(name, 'Nombre del ejercicio'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: muscle,
                    dropdownColor: dialogContext.colors.panel2,
                    style: TextStyle(color: dialogContext.colors.white),
                    decoration: _inputDecoration(dialogContext, 'Músculo'),
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
                    dropdownColor: dialogContext.colors.panel2,
                    style: TextStyle(color: dialogContext.colors.white),
                    decoration: _inputDecoration(dialogContext, 'Nivel'),
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
                  _button('GUARDAR CAMBIOS', dialogContext.colors.yellow,
                      () async {
                    if (name.text.trim().isEmpty) return;
                    final navigator = Navigator.of(dialogContext);
                    final messenger = ScaffoldMessenger.of(dialogContext);
                    final ctx = dialogContext;
                    setState(() {
                      exercise['name'] = name.text.trim();
                      exercise['muscle'] = muscle;
                      exercise['sets'] = int.tryParse(sets.text) ?? 3;
                      exercise['reps'] = int.tryParse(reps.text) ?? 12;
                      exercise['weight'] = double.tryParse(weight.text) ?? 0.0;
                      exercise['level'] = level;
                    });
                    navigator.pop();
                    await _saveLocalData();
                    messenger.showSnackBar(
                      SnackBar(
                        content:
                            const Text('Ejercicio actualizado correctamente'),
                        backgroundColor: ctx.colors.green,
                      ),
                    );
                  }, darkText: true),
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
      builder: (dialogContext) {
        return _dialog(
          title: 'ELIMINAR EJERCICIO',
          accent: dialogContext.colors.red,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: dialogContext.colors.red, size: 60),
              const SizedBox(height: 18),
              Text(
                '¿Eliminar "${exercise['name']}"?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: dialogContext.colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: BorderSide(color: dialogContext.colors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13)),
                      ),
                      child: Text('CANCELAR',
                          style: TextStyle(
                              color: dialogContext.colors.white,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final navigator = Navigator.of(dialogContext);
                        final messenger = ScaffoldMessenger.of(dialogContext);
                        final ctx = dialogContext;
                        setState(() => exercises.remove(exercise));
                        navigator.pop();
                        await _saveLocalData();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                                'Ejercicio "${exercise['name']}" eliminado'),
                            backgroundColor: ctx.colors.green,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: dialogContext.colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13)),
                      ),
                      child: const Text('ELIMINAR',
                          style: TextStyle(fontWeight: FontWeight.w900)),
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

  void addTrainer() {
    final name = TextEditingController();
    final specialty = TextEditingController();
    final phone = TextEditingController();
    final clientsCtrl = TextEditingController(text: '0');
    final schedule = TextEditingController(text: '06:00 - 14:00');
    double rating = 5.0;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return _dialog(
          title: 'NUEVO ENTRENADOR',
          accent: dialogContext.colors.red,
          child: StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(name, 'Nombre completo'),
                  const SizedBox(height: 12),
                  _field(specialty, 'Especialidad'),
                  const SizedBox(height: 12),
                  _field(phone, 'Teléfono'),
                  const SizedBox(height: 12),
                  _field(clientsCtrl, 'Cantidad de clientes',
                      keyboard: TextInputType.number),
                  const SizedBox(height: 12),
                  _field(schedule, 'Horario (ej: 06:00 - 14:00)'),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: dialogContext.colors.panel2,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: dialogContext.colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.star_rounded,
                                color: dialogContext.colors.yellow, size: 18),
                            const SizedBox(width: 8),
                            Text('Rating',
                                style: TextStyle(
                                  color: dialogContext.colors.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                )),
                            const Spacer(),
                            Text(rating.toStringAsFixed(1),
                                style: TextStyle(
                                  color: dialogContext.colors.yellow,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                )),
                          ],
                        ),
                        Slider(
                          value: rating,
                          min: 1,
                          max: 5,
                          divisions: 40,
                          activeColor: dialogContext.colors.yellow,
                          inactiveColor: dialogContext.colors.border,
                          label: rating.toStringAsFixed(1),
                          onChanged: (v) => setDialogState(() => rating = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _button('CREAR ENTRENADOR', dialogContext.colors.red,
                      () async {
                    if (name.text.trim().isEmpty) return;
                    final navigator = Navigator.of(dialogContext);
                    final messenger = ScaffoldMessenger.of(dialogContext);
                    final ctx = dialogContext;
                    final now = DateTime.now();
                    setState(() {
                      trainers.add({
                        'id': 't-${now.millisecondsSinceEpoch}',
                        'name': name.text.trim(),
                        'specialty': specialty.text.trim().isEmpty
                            ? 'General'
                            : specialty.text.trim(),
                        'phone': phone.text.trim().isEmpty
                            ? '+00 000 000000'
                            : phone.text.trim(),
                        'clients': int.tryParse(clientsCtrl.text) ?? 0,
                        'rating': rating,
                        'schedule': schedule.text.trim().isEmpty
                            ? '06:00 - 14:00'
                            : schedule.text.trim(),
                      });
                    });
                    navigator.pop();
                    await _saveLocalData();
                    messenger.showSnackBar(
                      SnackBar(
                        content: const Text('Entrenador creado correctamente'),
                        backgroundColor: ctx.colors.green,
                      ),
                    );
                  }, darkText: true),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void editTrainer(Map<String, dynamic> trainer) {
    final name = TextEditingController(text: trainer['name'].toString());
    final specialty =
        TextEditingController(text: trainer['specialty'].toString());
    final phone = TextEditingController(text: trainer['phone'].toString());
    final clientsCtrl =
        TextEditingController(text: trainer['clients'].toString());
    final schedule =
        TextEditingController(text: trainer['schedule'].toString());
    double rating = (trainer['rating'] as num?)?.toDouble() ?? 5.0;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return _dialog(
          title: 'EDITAR ENTRENADOR',
          accent: dialogContext.colors.yellow,
          child: StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(name, 'Nombre completo'),
                  const SizedBox(height: 12),
                  _field(specialty, 'Especialidad'),
                  const SizedBox(height: 12),
                  _field(phone, 'Teléfono'),
                  const SizedBox(height: 12),
                  _field(clientsCtrl, 'Cantidad de clientes',
                      keyboard: TextInputType.number),
                  const SizedBox(height: 12),
                  _field(schedule, 'Horario'),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: dialogContext.colors.panel2,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: dialogContext.colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.star_rounded,
                                color: dialogContext.colors.yellow, size: 18),
                            const SizedBox(width: 8),
                            Text('Rating',
                                style: TextStyle(
                                  color: dialogContext.colors.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                )),
                            const Spacer(),
                            Text(rating.toStringAsFixed(1),
                                style: TextStyle(
                                  color: dialogContext.colors.yellow,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                )),
                          ],
                        ),
                        Slider(
                          value: rating,
                          min: 1,
                          max: 5,
                          divisions: 40,
                          activeColor: dialogContext.colors.yellow,
                          inactiveColor: dialogContext.colors.border,
                          label: rating.toStringAsFixed(1),
                          onChanged: (v) => setDialogState(() => rating = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _button('GUARDAR CAMBIOS', dialogContext.colors.yellow,
                      () async {
                    if (name.text.trim().isEmpty) return;
                    final navigator = Navigator.of(dialogContext);
                    final messenger = ScaffoldMessenger.of(dialogContext);
                    final ctx = dialogContext;
                    setState(() {
                      trainer['name'] = name.text.trim();
                      trainer['specialty'] = specialty.text.trim();
                      trainer['phone'] = phone.text.trim();
                      trainer['clients'] = int.tryParse(clientsCtrl.text) ?? 0;
                      trainer['rating'] = rating;
                      trainer['schedule'] = schedule.text.trim();
                    });
                    navigator.pop();
                    await _saveLocalData();
                    messenger.showSnackBar(
                      SnackBar(
                        content:
                            const Text('Entrenador actualizado correctamente'),
                        backgroundColor: ctx.colors.green,
                      ),
                    );
                  }, darkText: true),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void deleteTrainer(Map<String, dynamic> trainer) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return _dialog(
          title: 'ELIMINAR ENTRENADOR',
          accent: dialogContext.colors.red,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: dialogContext.colors.red, size: 60),
              const SizedBox(height: 18),
              Text(
                '¿Eliminar a ${trainer['name']}?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: dialogContext.colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: BorderSide(color: dialogContext.colors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13)),
                      ),
                      child: Text('CANCELAR',
                          style: TextStyle(
                              color: dialogContext.colors.white,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final navigator = Navigator.of(dialogContext);
                        final messenger = ScaffoldMessenger.of(dialogContext);
                        final ctx = dialogContext;
                        setState(() => trainers.remove(trainer));
                        navigator.pop();
                        await _saveLocalData();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('${trainer['name']} eliminado'),
                            backgroundColor: ctx.colors.green,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: dialogContext.colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13)),
                      ),
                      child: const Text('ELIMINAR',
                          style: TextStyle(fontWeight: FontWeight.w900)),
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

  void addClassType() {
    final name = TextEditingController();
    int selectedIcon = 0xe4a4;
    final availableIcons = [
      {'code': 0xe4a4, 'icon': Icons.self_improvement},
      {'code': 0xe4a7, 'icon': Icons.directions_bike},
      {'code': 0xe4a8, 'icon': Icons.fitness_center},
      {'code': 0xe4a9, 'icon': Icons.sports_mma},
      {'code': 0xe4aa, 'icon': Icons.accessibility_new},
      {'code': 0xe4ab, 'icon': Icons.sports_gymnastics},
      {'code': 0xe4ac, 'icon': Icons.sports_martial_arts},
      {'code': 0xe4ad, 'icon': Icons.sports_handball},
    ];
    showDialog(
      context: context,
      builder: (dialogContext) {
        return _dialog(
          title: 'NUEVO TIPO DE CLASE',
          accent: dialogContext.colors.red,
          child: StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(name, 'Nombre (ej: YOGA, BOXEO)'),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: dialogContext.colors.panel2,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: dialogContext.colors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color:
                                dialogContext.colors.red.withValues(alpha: .15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: dialogContext.colors.red
                                  .withValues(alpha: .35),
                            ),
                          ),
                          child: Icon(_iconFromCodePoint(selectedIcon),
                              color: dialogContext.colors.red, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            name.text.isEmpty
                                ? 'VISTA PREVIA'
                                : name.text.toUpperCase(),
                            style: TextStyle(
                              color: dialogContext.colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('ICONO',
                        style: TextStyle(
                          color: dialogContext.colors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        )),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: availableIcons.map((ic) {
                      final code = ic['code'] as int;
                      final iconData = ic['icon'] as IconData;
                      final selected = selectedIcon == code;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedIcon = code),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: selected
                                ? dialogContext.colors.red
                                    .withValues(alpha: .20)
                                : dialogContext.colors.panel2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? dialogContext.colors.red
                                  : dialogContext.colors.border,
                              width: 2,
                            ),
                          ),
                          child: Icon(iconData,
                              color: selected
                                  ? dialogContext.colors.red
                                  : dialogContext.colors.muted,
                              size: 22),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  _button('CREAR TIPO', dialogContext.colors.red, () async {
                    if (name.text.trim().isEmpty) return;
                    final navigator = Navigator.of(dialogContext);
                    final messenger = ScaffoldMessenger.of(dialogContext);
                    final ctx = dialogContext;
                    final now = DateTime.now();
                    setState(() {
                      classTypes.add({
                        'id': 'ct-${now.millisecondsSinceEpoch}',
                        'name': name.text.trim().toUpperCase(),
                        'color': 0xFFFF1744,
                        'icon': selectedIcon,
                      });
                    });
                    navigator.pop();
                    await _saveLocalData();
                    messenger.showSnackBar(
                      SnackBar(
                        content:
                            const Text('Tipo de clase creado correctamente'),
                        backgroundColor: ctx.colors.green,
                      ),
                    );
                  }, darkText: true),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void editClassType(Map<String, dynamic> ct) {
    final name = TextEditingController(text: ct['name'].toString());
    int selectedIcon = ct['icon'] as int;
    final availableIcons = [
      {'code': 0xe4a4, 'icon': Icons.self_improvement},
      {'code': 0xe4a7, 'icon': Icons.directions_bike},
      {'code': 0xe4a8, 'icon': Icons.fitness_center},
      {'code': 0xe4a9, 'icon': Icons.sports_mma},
      {'code': 0xe4aa, 'icon': Icons.accessibility_new},
      {'code': 0xe4ab, 'icon': Icons.sports_gymnastics},
      {'code': 0xe4ac, 'icon': Icons.sports_martial_arts},
      {'code': 0xe4ad, 'icon': Icons.sports_handball},
    ];
    showDialog(
      context: context,
      builder: (dialogContext) {
        return _dialog(
          title: 'EDITAR TIPO DE CLASE',
          accent: dialogContext.colors.yellow,
          child: StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(name, 'Nombre'),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: dialogContext.colors.panel2,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: dialogContext.colors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color:
                                dialogContext.colors.red.withValues(alpha: .15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: dialogContext.colors.red
                                  .withValues(alpha: .35),
                            ),
                          ),
                          child: Icon(_iconFromCodePoint(selectedIcon),
                              color: dialogContext.colors.red, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            name.text.isEmpty
                                ? 'VISTA PREVIA'
                                : name.text.toUpperCase(),
                            style: TextStyle(
                              color: dialogContext.colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('ICONO',
                        style: TextStyle(
                          color: dialogContext.colors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        )),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: availableIcons.map((ic) {
                      final code = ic['code'] as int;
                      final iconData = ic['icon'] as IconData;
                      final selected = selectedIcon == code;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedIcon = code),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: selected
                                ? dialogContext.colors.red
                                    .withValues(alpha: .20)
                                : dialogContext.colors.panel2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? dialogContext.colors.red
                                  : dialogContext.colors.border,
                              width: 2,
                            ),
                          ),
                          child: Icon(iconData,
                              color: selected
                                  ? dialogContext.colors.red
                                  : dialogContext.colors.muted,
                              size: 22),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  _button('GUARDAR CAMBIOS', dialogContext.colors.yellow,
                      () async {
                    if (name.text.trim().isEmpty) return;
                    final navigator = Navigator.of(dialogContext);
                    final messenger = ScaffoldMessenger.of(dialogContext);
                    final ctx = dialogContext;
                    setState(() {
                      ct['name'] = name.text.trim().toUpperCase();
                      ct['color'] = 0xFFFF1744;
                      ct['icon'] = selectedIcon;
                    });
                    navigator.pop();
                    await _saveLocalData();
                    messenger.showSnackBar(
                      SnackBar(
                        content: const Text('Tipo actualizado correctamente'),
                        backgroundColor: ctx.colors.green,
                      ),
                    );
                  }, darkText: true),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void deleteClassType(Map<String, dynamic> ct) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return _dialog(
          title: 'ELIMINAR TIPO',
          accent: dialogContext.colors.red,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: dialogContext.colors.red, size: 60),
              const SizedBox(height: 18),
              Text('¿Eliminar "${ct['name']}"?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: dialogContext.colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  )),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: BorderSide(color: dialogContext.colors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13)),
                      ),
                      child: Text('CANCELAR',
                          style: TextStyle(
                              color: dialogContext.colors.white,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final navigator = Navigator.of(dialogContext);
                        final messenger = ScaffoldMessenger.of(dialogContext);
                        final ctx = dialogContext;
                        setState(() => classTypes.remove(ct));
                        navigator.pop();
                        await _saveLocalData();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Tipo "${ct['name']}" eliminado'),
                            backgroundColor: ctx.colors.green,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: dialogContext.colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13)),
                      ),
                      child: const Text('ELIMINAR',
                          style: TextStyle(fontWeight: FontWeight.w900)),
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

  void addClass() {
    final name = TextEditingController();
    final capacityCtrl = TextEditingController(text: '20');
    String type =
        classTypes.isNotEmpty ? classTypes.first['name'].toString() : 'YOGA';
    String day = 'LUNES';
    String time = '08:00';
    String trainerName =
        trainers.isNotEmpty ? trainers.first['name'].toString() : '';
    showDialog(
      context: context,
      builder: (dialogContext) {
        return _dialog(
          title: 'NUEVA CLASE',
          accent: dialogContext.colors.red,
          child: StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(name, 'Nombre de la clase'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: type,
                    dropdownColor: dialogContext.colors.panel2,
                    style: TextStyle(color: dialogContext.colors.white),
                    decoration: _inputDecoration(dialogContext, 'Tipo'),
                    items: classTypes.map((ct) {
                      final value = ct['name'].toString();
                      return DropdownMenuItem(value: value, child: Text(value));
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => type = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: day,
                    dropdownColor: dialogContext.colors.panel2,
                    style: TextStyle(color: dialogContext.colors.white),
                    decoration: _inputDecoration(dialogContext, 'Día'),
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
                    dropdownColor: dialogContext.colors.panel2,
                    style: TextStyle(color: dialogContext.colors.white),
                    decoration: _inputDecoration(dialogContext, 'Hora'),
                    items: const [
                      DropdownMenuItem(value: '06:00', child: Text('06:00')),
                      DropdownMenuItem(value: '08:00', child: Text('08:00')),
                      DropdownMenuItem(value: '10:00', child: Text('10:00')),
                      DropdownMenuItem(value: '12:00', child: Text('12:00')),
                      DropdownMenuItem(value: '14:00', child: Text('14:00')),
                      DropdownMenuItem(value: '16:00', child: Text('16:00')),
                      DropdownMenuItem(value: '18:00', child: Text('18:00')),
                      DropdownMenuItem(value: '20:00', child: Text('20:00')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => time = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: trainerName.isEmpty ? null : trainerName,
                    dropdownColor: dialogContext.colors.panel2,
                    style: TextStyle(color: dialogContext.colors.white),
                    decoration: _inputDecoration(dialogContext, 'Entrenador'),
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
                  _button('CREAR CLASE', dialogContext.colors.red, () async {
                    if (name.text.trim().isEmpty) return;
                    final navigator = Navigator.of(dialogContext);
                    final messenger = ScaffoldMessenger.of(dialogContext);
                    final ctx = dialogContext;
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
                    messenger.showSnackBar(
                      SnackBar(
                        content: const Text('Clase creada correctamente'),
                        backgroundColor: ctx.colors.green,
                      ),
                    );
                  }, darkText: true),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void editClass(Map<String, dynamic> classItem) {
    final name = TextEditingController(text: classItem['name'].toString());
    final capacityCtrl =
        TextEditingController(text: classItem['capacity'].toString());
    String type = classItem['type'].toString();
    String day = classItem['day'].toString();
    String time = classItem['time'].toString();
    String trainerName = classItem['trainer'].toString();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return _dialog(
          title: 'EDITAR CLASE',
          accent: dialogContext.colors.yellow,
          child: StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(name, 'Nombre de la clase'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: type,
                    dropdownColor: dialogContext.colors.panel2,
                    style: TextStyle(color: dialogContext.colors.white),
                    decoration: _inputDecoration(dialogContext, 'Tipo'),
                    items: classTypes.map((ct) {
                      final value = ct['name'].toString();
                      return DropdownMenuItem(value: value, child: Text(value));
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => type = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: day,
                    dropdownColor: dialogContext.colors.panel2,
                    style: TextStyle(color: dialogContext.colors.white),
                    decoration: _inputDecoration(dialogContext, 'Día'),
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
                    dropdownColor: dialogContext.colors.panel2,
                    style: TextStyle(color: dialogContext.colors.white),
                    decoration: _inputDecoration(dialogContext, 'Hora'),
                    items: const [
                      DropdownMenuItem(value: '06:00', child: Text('06:00')),
                      DropdownMenuItem(value: '08:00', child: Text('08:00')),
                      DropdownMenuItem(value: '10:00', child: Text('10:00')),
                      DropdownMenuItem(value: '12:00', child: Text('12:00')),
                      DropdownMenuItem(value: '14:00', child: Text('14:00')),
                      DropdownMenuItem(value: '16:00', child: Text('16:00')),
                      DropdownMenuItem(value: '18:00', child: Text('18:00')),
                      DropdownMenuItem(value: '20:00', child: Text('20:00')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => time = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: trainerName.isEmpty ? null : trainerName,
                    dropdownColor: dialogContext.colors.panel2,
                    style: TextStyle(color: dialogContext.colors.white),
                    decoration: _inputDecoration(dialogContext, 'Entrenador'),
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
                  _button('GUARDAR CAMBIOS', dialogContext.colors.yellow,
                      () async {
                    if (name.text.trim().isEmpty) return;
                    final navigator = Navigator.of(dialogContext);
                    final messenger = ScaffoldMessenger.of(dialogContext);
                    final ctx = dialogContext;
                    setState(() {
                      classItem['name'] = name.text.trim();
                      classItem['type'] = type;
                      classItem['day'] = day;
                      classItem['time'] = time;
                      classItem['trainer'] = trainerName;
                      classItem['capacity'] =
                          int.tryParse(capacityCtrl.text) ?? 20;
                    });
                    navigator.pop();
                    await _saveLocalData();
                    messenger.showSnackBar(
                      SnackBar(
                        content: const Text('Clase actualizada correctamente'),
                        backgroundColor: ctx.colors.green,
                      ),
                    );
                  }, darkText: true),
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
      builder: (dialogContext) {
        return _dialog(
          title: 'ELIMINAR CLASE',
          accent: dialogContext.colors.red,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: dialogContext.colors.red, size: 60),
              const SizedBox(height: 18),
              Text('¿Eliminar la clase "${classItem['name']}"?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: dialogContext.colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  )),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: BorderSide(color: dialogContext.colors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13)),
                      ),
                      child: Text('CANCELAR',
                          style: TextStyle(
                              color: dialogContext.colors.white,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final navigator = Navigator.of(dialogContext);
                        final messenger = ScaffoldMessenger.of(dialogContext);
                        final ctx = dialogContext;
                        setState(() => classes.remove(classItem));
                        navigator.pop();
                        await _saveLocalData();
                        messenger.showSnackBar(
                          SnackBar(
                            content:
                                Text('Clase "${classItem['name']}" eliminada'),
                            backgroundColor: ctx.colors.green,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: dialogContext.colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13)),
                      ),
                      child: const Text('ELIMINAR',
                          style: TextStyle(fontWeight: FontWeight.w900)),
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

  Widget _mobileDrawer() {
    final items = [
      [Icons.grid_view_rounded, 'Command Center'],
      [Icons.people_alt_rounded, 'Clientes'],
      [Icons.qr_code_scanner_rounded, 'Acceso QR'],
      [Icons.card_membership_rounded, 'Membresías'],
      [Icons.payments_rounded, 'Finanzas'],
      [Icons.fitness_center_rounded, 'Entrenamiento'],
      [Icons.notifications_active_rounded, 'Alertas'],
      [Icons.settings_rounded, 'Configuración'],
    ];
    return Drawer(
      backgroundColor: context.colors.panel,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: context.colors.red,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.bolt_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SYNTHETIX',
                            style: TextStyle(
                              color: context.colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                            )),
                        const SizedBox(height: 2),
                        Text('GYM OS PRO',
                            style: TextStyle(
                              color: context.colors.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            )),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon:
                        Icon(Icons.close_rounded, color: context.colors.muted),
                  ),
                ],
              ),
            ),
            Divider(color: context.colors.border, height: 1),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final selected = index == _section;
                  final isAlerts = index == 6;
                  final ac = alertCount(context) + renewalRequests.length;
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          _goToSection(index);
                          Navigator.pop(context);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 15),
                          decoration: BoxDecoration(
                            color: selected
                                ? context.colors.red.withValues(alpha: .13)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected
                                  ? context.colors.red.withValues(alpha: .45)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(items[index][0] as IconData,
                                  color: selected
                                      ? context.colors.red
                                      : context.colors.muted,
                                  size: 22),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(items[index][1] as String,
                                    style: TextStyle(
                                      color: selected
                                          ? context.colors.white
                                          : context.colors.muted,
                                      fontSize: 14,
                                      fontWeight: selected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                    )),
                              ),
                              if (isAlerts && ac > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: context.colors.red,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('$ac',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      )),
                                ),
                              if (selected)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                      color: context.colors.red,
                                      shape: BoxShape.circle),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => themeController.toggle(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 15),
                    decoration: BoxDecoration(
                      color: context.colors.panel2,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          themeController.isDark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          color: context.colors.red,
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            themeController.isDark
                                ? 'Cambiar a modo claro'
                                : 'Cambiar a modo oscuro',
                            style: TextStyle(
                              color: context.colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.pop(context);
                    confirmLogout();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 15),
                    decoration: BoxDecoration(
                      color: context.colors.red.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: context.colors.red.withValues(alpha: .30)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded,
                            color: context.colors.red, size: 22),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text('CERRAR SESIÓN',
                              style: TextStyle(
                                color: context.colors.red,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              )),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.colors.panel2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.colors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_rounded,
                        color: context.colors.green, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('SISTEMA OPERATIVO',
                          style: TextStyle(
                            color: context.colors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          )),
                    ),
                    CircleAvatar(
                        radius: 4, backgroundColor: context.colors.green),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _desktop() {
    return Row(
      children: [
        _sidebar(),
        Expanded(
          child: Column(
            children: [
              _header(),
              Expanded(
                child: loadingData
                    ? Center(
                        child: CircularProgressIndicator(
                            color: context.colors.red))
                    : _content(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mobile() {
    final titles = [
      'Command Center',
      'Clientes',
      'Acceso QR',
      'Membresías',
      'Finanzas',
      'Entrenamiento',
      'Alertas',
      'Configuración',
    ];
    final title = (_section >= 0 && _section < titles.length)
        ? titles[_section]
        : 'Command Center';

    final canLeaveApp = _section == 0 && _sectionHistory.isEmpty;

    return PopScope(
      canPop: canLeaveApp,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _goBackInApp();
      },
      child: Scaffold(
        backgroundColor: context.colors.bg,
        drawer: _mobileDrawer(),
        appBar: AppBar(
          backgroundColor: context.colors.panel,
          elevation: 0,
          centerTitle: false,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: Icon(
              canLeaveApp ? Icons.menu_rounded : Icons.arrow_back_rounded,
              color: context.colors.white,
            ),
            onPressed: () {
              if (canLeaveApp) {
                _scaffoldKey.currentState?.openDrawer();
              } else {
                _goBackInApp();
              }
            },
          ),
          title: Text(
            title,
            style: TextStyle(
              color: context.colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          actions: [
            if (_section != 0)
              IconButton(
                tooltip: 'Inicio',
                icon: Icon(Icons.home_rounded, color: context.colors.red),
                onPressed: () {
                  _sectionHistory.clear();
                  setState(() => _section = 0);
                },
              ),
            IconButton(
              tooltip: 'Notificaciones',
              icon: Icon(Icons.notifications_none_rounded,
                  color: context.colors.white),
              onPressed: showNotifications,
            ),
            const SizedBox(width: 4),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: context.colors.border),
          ),
        ),
        body: loadingData
            ? Center(
                child: CircularProgressIndicator(color: context.colors.red))
            : Stack(
                children: [
                  _content(),
                  if (_section != 0)
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: FloatingActionButton.small(
                        backgroundColor: context.colors.panel,
                        foregroundColor: context.colors.red,
                        elevation: 4,
                        tooltip: 'Regresar',
                        onPressed: _goBackInApp,
                        child: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                ],
              ),
      ),
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
      [Icons.notifications_active_rounded, 'Alertas'],
      [Icons.settings_rounded, 'Configuración'],
    ];
    return Container(
      width: 260,
      color: context.colors.panel,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.colors.red,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.bolt_rounded,
                    color: Colors.white, size: 27),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('SYNTHETIX\nGYM OS PRO',
                    style: TextStyle(
                      color: context.colors.white,
                      fontSize: 15,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.3,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 35),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final selected = index == _section;
                final isAlerts = index == 6;
                final ac = alertCount(context) + renewalRequests.length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _goToSection(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: selected
                              ? context.colors.red.withValues(alpha: .13)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? context.colors.red.withValues(alpha: .45)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(items[index][0] as IconData,
                                color: selected
                                    ? context.colors.red
                                    : context.colors.muted,
                                size: 21),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Text(items[index][1] as String,
                                  style: TextStyle(
                                    color: selected
                                        ? context.colors.white
                                        : context.colors.muted,
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  )),
                            ),
                            if (isAlerts && ac > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: context.colors.red,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text('$ac',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    )),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => themeController.toggle(),
              child: Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: context.colors.panel2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.colors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      themeController.isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      color: context.colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        themeController.isDark ? 'Modo claro' : 'Modo oscuro',
                        style: TextStyle(
                          color: context.colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: confirmLogout,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.colors.red.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: context.colors.red.withValues(alpha: .30)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded,
                        color: context.colors.red, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('CERRAR SESIÓN',
                          style: TextStyle(
                            color: context.colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          )),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final ac = alertCount(context) + renewalRequests.length;
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: context.colors.bg,
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('COMMAND CENTER',
                    style: TextStyle(
                      color: context.colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    )),
                const SizedBox(height: 3),
                Text('Control operativo del gimnasio',
                    style:
                        TextStyle(color: context.colors.muted, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => loadAllData(),
            icon: Icon(Icons.refresh_rounded, color: context.colors.green),
            tooltip: 'Recargar datos',
          ),
          const SizedBox(width: 4),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: () => themeController.toggle(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: context.colors.panel,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: context.colors.border),
                ),
                child: Icon(
                  themeController.isDark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                  color: context.colors.red,
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: () => _goToSection(7),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: context.colors.panel,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: context.colors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.settings_rounded,
                        color: context.colors.red, size: 18),
                    const SizedBox(width: 8),
                    Text('Config',
                        style: TextStyle(
                          color: context.colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        )),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Stack(
            children: [
              IconButton(
                onPressed: showNotifications,
                icon: Icon(Icons.notifications_none_rounded,
                    color: context.colors.white),
              ),
              if (ac > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    decoration: BoxDecoration(
                      color: context.colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text('$ac',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        )),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: context.colors.red, width: 2),
            ),
            child: Center(
              child: Text('A',
                  style: TextStyle(
                    color: context.colors.white,
                    fontWeight: FontWeight.w900,
                  )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    final isMobile = MediaQuery.of(context).size.width < 850;
    if (_section == 1) return _clientsPage();
    if (_section == 2) {
      return isMobile ? _qrCenterMobile() : _qrCenter();
    }
    if (_section == 3) {
      return isMobile ? _plansPageMobile() : _plansPage();
    }
    if (_section == 4) return _financePage();
    if (_section == 5) return _trainingPage();
    if (_section == 6) {
      return isMobile ? _alertsPageMobile() : _alertsPage();
    }
    if (_section == 7) return _currencyPage();
    if (isMobile) {
      final ac = alertCount(context) + renewalRequests.length;
      final activeCount = members
          .where((m) => m['status'].toString().toUpperCase() == 'ACTIVO')
          .length;
      final expiringCount = members
          .where((m) => m['status'].toString().toUpperCase() == 'POR VENCER')
          .length;
      final expiredCount = members
          .where((m) => m['status'].toString().toUpperCase() == 'VENCIDO')
          .length;
      return AdminHomeMobile(
        inside: inside,
        capacity: capacity,
        income: totalIncome,
        activeMembers: activeCount,
        expiringSoon: expiringCount,
        expired: expiredCount,
        activities: activities,
        notificationCount: ac,
        adminName: 'Admin',
        onScan: showAccessScanner,
        onNewPayment: newPayment,
        onNewMember: addMember,
        onOpenNotifications: showNotifications,
        onOpenMore: () => _scaffoldKey.currentState?.openDrawer(),
        onOpenMemberships: () => _goToSection(3),
        onOpenClients: () => _goToSection(1),
        onOpenFinance: () => _goToSection(4),
      );
    }
    return _dashboardContent();
  }

  void showNotifications() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            final alerts = activeAlerts(sheetContext);
            final renewals =
                renewalRequests.where((r) => r['read'] != true).toList();
            return Container(
              margin: EdgeInsets.only(
                  top: MediaQuery.of(sheetContext).padding.top + 40),
              decoration: BoxDecoration(
                color: sheetContext.colors.bg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: sheetContext.colors.muted.withValues(alpha: .4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color:
                                sheetContext.colors.red.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            Icons.notifications_active_rounded,
                            color: sheetContext.colors.red,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Notificaciones',
                                  style: TextStyle(
                                    color: sheetContext.colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  )),
                              const SizedBox(height: 2),
                              Text(
                                (alerts.length + renewals.length) == 0
                                    ? 'Todo en orden'
                                    : '${alerts.length + renewals.length} pendientes',
                                style: TextStyle(
                                  color: sheetContext.colors.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: Icon(Icons.close_rounded,
                              color: sheetContext.colors.muted, size: 22),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight:
                            MediaQuery.of(sheetContext).size.height * 0.65,
                      ),
                      child: (alerts.isEmpty && renewals.isEmpty)
                          ? Padding(
                              padding: const EdgeInsets.all(40),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.check_circle_rounded,
                                        color: sheetContext.colors.green,
                                        size: 50),
                                    const SizedBox(height: 14),
                                    Text('Sin notificaciones',
                                        style: TextStyle(
                                          color: sheetContext.colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                        )),
                                    const SizedBox(height: 6),
                                    Text('Todo está al día',
                                        style: TextStyle(
                                          color: sheetContext.colors.muted,
                                          fontSize: 12,
                                        )),
                                  ],
                                ),
                              ),
                            )
                          : ListView(
                              shrinkWrap: true,
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              children: [
                                ...renewals.map((r) => Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: sheetContext.colors.panel,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: sheetContext.colors.yellow
                                              .withValues(alpha: .40),
                                        ),
                                      ),
                                      child: Row(children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: sheetContext.colors.yellow
                                                .withValues(alpha: .12),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Icon(Icons.autorenew_rounded,
                                              color: sheetContext.colors.yellow,
                                              size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(r['name'].toString(),
                                                  style: TextStyle(
                                                    color: sheetContext
                                                        .colors.white,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w800,
                                                  )),
                                              const SizedBox(height: 3),
                                              Text(
                                                  'Solicitó renovación · ${r['plan']}',
                                                  style: TextStyle(
                                                    color: sheetContext
                                                        .colors.muted,
                                                    fontSize: 11,
                                                  )),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () {
                                            setState(() {
                                              r['read'] = true;
                                            });
                                            _saveLocalData();
                                            setModalState(() {});
                                          },
                                          icon: Icon(Icons.close_rounded,
                                              color: sheetContext.colors.muted,
                                              size: 18),
                                        ),
                                      ]),
                                    )),
                                ...alerts.map((alert) {
                                  final color = alert['color'] as Color;
                                  final icon = alert['icon'] as IconData;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: sheetContext.colors.panel,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: color.withValues(alpha: .25)),
                                    ),
                                    child: Row(children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: .12),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child:
                                            Icon(icon, color: color, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(alert['title'].toString(),
                                                style: TextStyle(
                                                  color:
                                                      sheetContext.colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                            const SizedBox(height: 3),
                                            Text(alert['subtitle'].toString(),
                                                style: TextStyle(
                                                  color:
                                                      sheetContext.colors.muted,
                                                  fontSize: 11,
                                                ),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () {
                                          dismissAlert(alert['id'].toString());
                                          setModalState(() {});
                                        },
                                        icon: Icon(Icons.close_rounded,
                                            color: sheetContext.colors.muted,
                                            size: 18),
                                      ),
                                    ]),
                                  );
                                }),
                              ],
                            ),
                    ),
                  ),
                  if (alerts.isNotEmpty || renewals.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _goToSection(6);
                          },
                          icon: const Icon(Icons.list_rounded, size: 18),
                          label: const Text(
                            'VER TODAS LAS ALERTAS',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: sheetContext.colors.red,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

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
                  context.colors.red,
                  addMember,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _quickAction(
                  Icons.payments_rounded,
                  'NUEVO PAGO',
                  context.colors.green,
                  newPayment,
                  darkText: true,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _quickAction(
                  Icons.qr_code_scanner_rounded,
                  'ESCANEAR ACCESO',
                  context.colors.blue,
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
              Expanded(flex: 3, child: _activityCard()),
              const SizedBox(width: 18),
              Expanded(flex: 2, child: _plansCard()),
            ],
          ),
          const SizedBox(height: 24),
          _membersCard(),
        ],
      ),
    );
  }

  Widget _hero() {
    final percent = (occupancy * 100).round();
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: context.colors.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.colors.border),
        boxShadow: [
          BoxShadow(
            color: context.colors.red.withValues(alpha: .08),
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
                Text('CONTROL EN TIEMPO REAL',
                    style: TextStyle(
                      color: context.colors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    )),
                const SizedBox(height: 10),
                Text('AFORO DEL GIMNASIO',
                    style: TextStyle(
                      color: context.colors.white,
                      fontSize: 31,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    )),
                const SizedBox(height: 8),
                Text(
                    '$inside personas dentro · ${capacity - inside} espacios disponibles',
                    style:
                        TextStyle(color: context.colors.muted, fontSize: 14)),
                const SizedBox(height: 22),
                Row(
                  children: [
                    _statusChip('$percent% OCUPADO', context.colors.red),
                    const SizedBox(width: 10),
                    _statusChip('OPERATIVO', context.colors.green),
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
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 1400),
                  curve: Curves.easeOutCubic,
                  tween: Tween(begin: 0.0, end: occupancy),
                  builder: (context, value, _) {
                    return CustomPaint(
                      size: const Size(190, 190),
                      painter: _OccupancyPainter(
                        percentage: value,
                        trackColor: context.colors.border,
                        progressColor: context.colors.red,
                      ),
                    );
                  },
                ),
                if (loadingCheckins)
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                        color: context.colors.red, strokeWidth: 3),
                  )
                else
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$inside',
                          style: TextStyle(
                            color: context.colors.white,
                            fontSize: 43,
                            fontWeight: FontWeight.w900,
                          )),
                      Text('DENTRO',
                          style: TextStyle(
                            color: context.colors.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          )),
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
        _metric('INGRESOS', formatPrice(income), Icons.payments_rounded,
            context.colors.green,
            trend: '+14.2%',
            subtitle: 'este mes',
            chartData: const [0.4, 0.5, 0.45, 0.6, 0.55, 0.7, 0.85, 1.0]),
        _metric('MIEMBROS ACTIVOS', activeMembers.toString(),
            Icons.people_alt_rounded, context.colors.blue,
            trend: '+8.4%',
            subtitle: 'vs mes anterior',
            chartData: const [0.5, 0.55, 0.6, 0.58, 0.7, 0.75, 0.85, 1.0]),
        _metric(
            'POR VENCER',
            members.where((m) => m['status'] == 'POR VENCER').length.toString(),
            Icons.warning_amber_rounded,
            context.colors.yellow,
            trend: '7 días',
            subtitle: 'requieren atención',
            chartData: const [0.3, 0.4, 0.35, 0.5, 0.45, 0.55, 0.5, 0.6]),
        _metric(
            'VENCIDOS',
            members.where((m) => m['status'] == 'VENCIDO').length.toString(),
            Icons.block_rounded,
            context.colors.red,
            trend: '-3.1%',
            subtitle: 'vs mes anterior',
            chartData: const [0.9, 0.8, 0.85, 0.7, 0.65, 0.6, 0.55, 0.5]),
      ],
    );
  }

  Widget _activityCard() {
    return _card(
      title: 'ACTIVIDAD RECIENTE',
      action: 'VER TODO',
      onAction: showActivity,
      child: activities.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('Sin actividad reciente',
                    style: TextStyle(color: context.colors.muted)),
              ),
            )
          : Column(
              children: activities.take(5).map((a) {
                Color color = context.colors.blue;
                if (a['type'] == 'ENTRADA') color = context.colors.green;
                if (a['type'] == 'SALIDA') color = context.colors.blue;
                if (a['type'] == 'PAGO') color = context.colors.yellow;
                if (a['type'] == 'BLOQUEADO') color = context.colors.red;
                if (a['type'] == 'RENOVACIÓN') color = context.colors.yellow;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.bolt_rounded, color: color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a['name'] ?? '',
                                  style: TextStyle(
                                    color: context.colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  )),
                              const SizedBox(height: 2),
                              Text(a['type'] ?? '',
                                  style: TextStyle(
                                      color: context.colors.muted,
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                        Text(a['time'] ?? '',
                            style: TextStyle(
                                color: context.colors.muted, fontSize: 11)),
                      ],
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
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('Sin planes registrados',
                    style: TextStyle(color: context.colors.muted)),
              ),
            )
          : Column(
              children: plans.take(4).map((p) {
                final price = (p['price'] as num).toDouble();
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: context.colors.panel2,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 55,
                        decoration: BoxDecoration(
                          color: context.colors.red,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p['name'].toString(),
                                style: TextStyle(
                                  color: context.colors.white,
                                  fontWeight: FontWeight.w900,
                                )),
                            const SizedBox(height: 3),
                            Text('${p['days']} días · ${p['access']}',
                                style: TextStyle(
                                  color: context.colors.muted,
                                  fontSize: 11,
                                )),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(formatPrice(price),
                              style: TextStyle(
                                color: context.colors.green,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              )),
                          if (showConversion)
                            Text(formatPriceSecondary(price),
                                style: TextStyle(
                                  color: context.colors.muted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                )),
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
            style: TextStyle(color: context.colors.white),
            decoration: _inputDecoration(context, 'Buscar miembro',
                prefixIcon: Icons.search_rounded),
          ),
          const SizedBox(height: 14),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('Sin miembros registrados',
                    style: TextStyle(color: context.colors.muted)),
              ),
            )
          else
            ...filtered.map((m) {
              final status = m['status'].toString();
              Color color = context.colors.green;
              if (status == 'POR VENCER') color = context.colors.yellow;
              if (status == 'VENCIDO') color = context.colors.red;
              if (status == 'PENDIENTE') color = context.colors.red;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => showClientDetail(m),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: color.withValues(alpha: .15),
                          child: Text(
                            m['name'].toString().isEmpty
                                ? '?'
                                : m['name']
                                    .toString()
                                    .substring(0, 1)
                                    .toUpperCase(),
                            style: TextStyle(
                                color: color, fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m['name'].toString(),
                                  style: TextStyle(
                                    color: context.colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  )),
                              const SizedBox(height: 2),
                              Text('${m['plan']} · vence ${m['expiry']}',
                                  style: TextStyle(
                                      color: context.colors.muted,
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                        _statusChip(status, color),
                        const SizedBox(width: 4),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert_rounded,
                              color: context.colors.muted, size: 20),
                          color: context.colors.panel2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: context.colors.border),
                          ),
                          onSelected: (value) {
                            if (value == 'edit') editMember(m);
                            if (value == 'delete') deleteMember(m);
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem<String>(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_rounded,
                                      color: context.colors.yellow, size: 18),
                                  const SizedBox(width: 10),
                                  Text('Editar',
                                      style: TextStyle(
                                          color: context.colors.white)),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_rounded,
                                      color: context.colors.red, size: 18),
                                  const SizedBox(width: 10),
                                  Text('Eliminar',
                                      style: TextStyle(
                                          color: context.colors.white)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _loginScreen() {
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: Stack(
        children: [
          Positioned(
            top: -150,
            right: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    context.colors.red.withValues(alpha: .18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -200,
            left: -150,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    context.colors.blue.withValues(alpha: .15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: _loginContent(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loginContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _loginLogo(),
        const SizedBox(height: 40),
        if (loginScreen == 'choose') ...[
          _loginRoleCard(
            icon: Icons.shield_rounded,
            title: 'ADMINISTRADOR',
            subtitle: 'Acceso con PIN de seguridad',
            color: context.colors.red,
            onTap: () => setState(() => loginScreen = 'admin'),
          ),
          const SizedBox(height: 14),
          _loginRoleCard(
            icon: Icons.person_rounded,
            title: 'CLIENTE',
            subtitle: 'Ingresa con tu cédula',
            color: context.colors.blue,
            onTap: () => setState(() => loginScreen = 'client'),
          ),
        ] else if (loginScreen == 'admin') ...[
          _loginHeader(
            icon: Icons.shield_rounded,
            title: 'ACCESO ADMIN',
            subtitle: 'Ingresa tu PIN de 4 dígitos',
            color: context.colors.red,
          ),
          const SizedBox(height: 32),
          _pinInput(),
          const SizedBox(height: 24),
          _primaryButton(
            text: isPinLocked ? 'BLOQUEADO ${pinLockSecondsLeft}s' : 'INGRESAR',
            color: context.colors.red,
            onTap: isPinLocked ? null : tryAdminLogin,
            icon: Icons.arrow_forward_rounded,
          ),
          const SizedBox(height: 16),
          _backLink(() => setState(() => loginScreen = 'choose')),
        ] else if (loginScreen == 'client') ...[
          _loginHeader(
            icon: Icons.person_rounded,
            title: 'ACCESO CLIENTE',
            subtitle: 'Ingresa con tu número de cédula',
            color: context.colors.blue,
          ),
          const SizedBox(height: 32),
          _textInputField(
            controller: clientCedulaController,
            label: 'Cédula',
            hint: 'Ej: 12345678',
            icon: Icons.badge_rounded,
            keyboard: TextInputType.number,
            accentColor: context.colors.blue,
          ),
          const SizedBox(height: 24),
          _primaryButton(
            text: 'INGRESAR',
            color: context.colors.blue,
            onTap: tryClientLogin,
            icon: Icons.arrow_forward_rounded,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                  child: Container(height: 1, color: context.colors.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '¿NUEVO AQUÍ?',
                  style: TextStyle(
                    color: context.colors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
              Expanded(
                  child: Container(height: 1, color: context.colors.border)),
            ],
          ),
          const SizedBox(height: 20),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() {
              loginScreen = 'register';
              regSelectedPlan = '';
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              decoration: BoxDecoration(
                color: context.colors.panel2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: context.colors.blue.withValues(alpha: .45),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_add_alt_1_rounded,
                    color: context.colors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.colors.muted,
                        ),
                        children: [
                          const TextSpan(text: '¿No tienes cuenta? '),
                          TextSpan(
                            text: 'Regístrate aquí',
                            style: TextStyle(
                              color: context.colors.blue,
                              fontWeight: FontWeight.w900,
                              decoration: TextDecoration.underline,
                              decorationColor: context.colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _backLink(() => setState(() => loginScreen = 'choose')),
        ] else if (loginScreen == 'register') ...[
          _loginHeader(
            icon: Icons.rocket_launch_rounded,
            title: 'CREAR CUENTA',
            subtitle: 'Únete a Synthetix Gym OS',
            color: context.colors.green,
          ),
          const SizedBox(height: 32),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'DATOS PERSONALES',
              style: TextStyle(
                color: context.colors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _textInputField(
            controller: regNameController,
            label: 'Nombre completo',
            hint: 'Ej: Juan Pérez',
            icon: Icons.person_rounded,
            accentColor: context.colors.green,
          ),
          const SizedBox(height: 12),
          _textInputField(
            controller: regCedulaController,
            label: 'Cédula',
            hint: 'Ej: 12345678',
            icon: Icons.badge_rounded,
            keyboard: TextInputType.number,
            accentColor: context.colors.green,
          ),
          const SizedBox(height: 12),
          _textInputField(
            controller: regPhoneController,
            label: 'Teléfono',
            hint: 'Ej: +58 412 1234567',
            icon: Icons.phone_rounded,
            keyboard: TextInputType.phone,
            accentColor: context.colors.green,
          ),
          const SizedBox(height: 28),
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Icon(Icons.card_membership_rounded,
                    color: context.colors.green, size: 16),
                const SizedBox(width: 8),
                Text(
                  'SELECCIONA TU PLAN',
                  style: TextStyle(
                    color: context.colors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (plans.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.colors.panel2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.colors.border),
              ),
              child: Center(
                child: Text('No hay planes disponibles',
                    style: TextStyle(color: context.colors.muted)),
              ),
            )
          else
            ...plans.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _planSelectorCard(p),
                )),
          const SizedBox(height: 24),
          _primaryButton(
            text: regLoading ? 'ENVIANDO...' : 'ENVIAR REGISTRO',
            color: context.colors.green,
            onTap: regLoading ? null : tryClientRegister,
            icon: Icons.send_rounded,
            darkText: true,
          ),
          const SizedBox(height: 16),
          _backLink(() => setState(() => loginScreen = 'client')),
        ] else if (loginScreen == 'registered') ...[
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: context.colors.panel,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: context.colors.green.withValues(alpha: .45),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: context.colors.green.withValues(alpha: .12),
                  blurRadius: 40,
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: context.colors.green.withValues(alpha: .12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.colors.green.withValues(alpha: .35),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: context.colors.green,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  '¡REGISTRO ENVIADO!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tu cuenta está PENDIENTE.\nEl administrador la aprobará pronto.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.colors.muted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                _primaryButton(
                  text: 'VOLVER AL INICIO',
                  color: context.colors.green,
                  onTap: () => setState(() => loginScreen = 'choose'),
                  icon: Icons.home_rounded,
                  darkText: true,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _loginLogo() {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: context.colors.red,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: context.colors.red.withValues(alpha: .45),
                blurRadius: 35,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 50),
        ),
        const SizedBox(height: 20),
        Text(
          'SYNTHETIX',
          style: TextStyle(
            color: context.colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'GYM OS PRO',
          style: TextStyle(
            color: context.colors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }

  Widget _loginHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: color.withValues(alpha: .35),
              width: 1.5,
            ),
          ),
          child: Icon(icon, color: color, size: 30),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.colors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _loginRoleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.colors.panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: color.withValues(alpha: .35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: .08),
                blurRadius: 25,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: color.withValues(alpha: .35),
                  ),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: context.colors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: color,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pinInput() {
    return TextField(
      controller: pinController,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: 4,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: context.colors.white,
        fontSize: 28,
        letterSpacing: 16,
        fontWeight: FontWeight.w900,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: '••••',
        hintStyle: TextStyle(
          color: context.colors.muted.withValues(alpha: .5),
          letterSpacing: 16,
        ),
        filled: true,
        fillColor: context.colors.panel2,
        contentPadding: const EdgeInsets.symmetric(vertical: 22),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: context.colors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: context.colors.red, width: 2),
        ),
      ),
    );
  }

  Widget _textInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color accentColor,
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      style: TextStyle(
        color: context.colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: context.colors.muted,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: TextStyle(
          color: context.colors.muted.withValues(alpha: .5),
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: accentColor, size: 20),
        filled: true,
        fillColor: context.colors.panel2,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.colors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accentColor, width: 2),
        ),
      ),
    );
  }

  Widget _planSelectorCard(Map<String, dynamic> plan) {
    final name = plan['name'].toString();
    final price = (plan['price'] as num).toDouble();
    final days = plan['days'].toString();
    final access = plan['access'].toString();
    final isSelected = regSelectedPlan == name;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => regSelectedPlan = name),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? context.colors.red.withValues(alpha: .12)
                : context.colors.panel2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? context.colors.red : context.colors.border,
              width: isSelected ? 2 : 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: context.colors.red.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.colors.red.withValues(alpha: .35),
                  ),
                ),
                child: Icon(Icons.card_membership_rounded,
                    color: context.colors.red, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.toUpperCase(),
                      style: TextStyle(
                        color: context.colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$days días · $access',
                      style: TextStyle(
                        color: context.colors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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
                    style: TextStyle(
                      color: context.colors.red,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  if (showConversion) ...[
                    const SizedBox(height: 3),
                    Text(
                      formatPriceSecondary(price),
                      style: TextStyle(
                        color: context.colors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 10),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? context.colors.red : Colors.transparent,
                  border: Border.all(
                    color:
                        isSelected ? context.colors.red : context.colors.border,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 16)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String text,
    required Color color,
    required VoidCallback? onTap,
    IconData? icon,
    bool darkText = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          disabledBackgroundColor: color.withValues(alpha: .4),
          disabledForegroundColor: Colors.white.withValues(alpha: .5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 1,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 10),
              Icon(icon, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  Widget _backLink(VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back_rounded,
                  color: context.colors.muted, size: 16),
              const SizedBox(width: 8),
              Text(
                'Volver',
                style: TextStyle(
                  color: context.colors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _clientHome() {
    final client = loggedClient;
    if (client == null) {
      return Scaffold(
        backgroundColor: context.colors.bg,
        body: Center(
          child:
              Text('Sin sesión', style: TextStyle(color: context.colors.muted)),
        ),
      );
    }
    final name = client['name']?.toString() ?? 'Cliente';
    final routineName = client['assignedRoutine']?.toString() ?? '';
    final status = (client['status']?.toString() ?? 'ACTIVO').toUpperCase();
    final isBlocked = status != 'ACTIVO';
    final statusColor = isBlocked ? context.colors.red : context.colors.green;
    final plan = client['plan']?.toString() ?? '—';
    final expiry = client['expiry']?.toString() ?? '—';
    final attendance = (client['attendance'] as num?)?.toInt() ?? 0;
    final qrCode = client['qrCode']?.toString() ?? '';
    final todayClasses = _classesToday();
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: context.colors.red,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hola,',
                            style: TextStyle(
                              color: context.colors.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            )),
                        const SizedBox(height: 2),
                        Text(name,
                            style: TextStyle(
                              color: context.colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => themeController.toggle(),
                    icon: Icon(
                      themeController.isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      color: context.colors.red,
                      size: 22,
                    ),
                  ),
                  IconButton(
                    onPressed: confirmLogout,
                    icon: Icon(Icons.logout_rounded,
                        color: context.colors.red, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.colors.panel,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: statusColor.withValues(alpha: .35),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: statusColor.withValues(alpha: .35)),
                      ),
                      child: Icon(
                        isBlocked
                            ? Icons.block_rounded
                            : Icons.verified_rounded,
                        color: statusColor,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MI MEMBRESÍA',
                              style: TextStyle(
                                color: context.colors.muted,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              )),
                          const SizedBox(height: 4),
                          Text(plan,
                              style: TextStyle(
                                color: context.colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              )),
                          const SizedBox(height: 2),
                          Text('Vence: $expiry',
                              style: TextStyle(
                                color: context.colors.muted,
                                fontSize: 11,
                              )),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                            color: statusColor.withValues(alpha: .45)),
                      ),
                      child: Text(status,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          )),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: openClientQrScanner,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: context.colors.red,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.red.withValues(alpha: .40),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .20),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.qr_code_scanner_rounded,
                              color: Colors.white, size: 34),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ESCANEAR ACCESO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Escanea el QR del gimnasio para entrar o salir',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .85),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 24),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: requestRenewal,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: context.colors.panel,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: context.colors.yellow.withValues(alpha: .45),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: context.colors.yellow.withValues(alpha: .15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.autorenew_rounded,
                              color: context.colors.yellow, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('RENOVAR MEMBRESÍA',
                                  style: TextStyle(
                                    color: context.colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  )),
                              const SizedBox(height: 3),
                              Text('Solicita renovación al gimnasio',
                                  style: TextStyle(
                                    color: context.colors.muted,
                                    fontSize: 11,
                                  )),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded,
                            color: context.colors.yellow, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => openGymWhatsApp(clientName: name),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: context.colors.panel,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: context.colors.green.withValues(alpha: .40),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: context.colors.green.withValues(alpha: .15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: FaIcon(FontAwesomeIcons.whatsapp,
                              color: context.colors.green, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('CONTACTAR GIMNASIO',
                                  style: TextStyle(
                                    color: context.colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  )),
                              const SizedBox(height: 3),
                              Text('Escríbenos por WhatsApp',
                                  style: TextStyle(
                                    color: context.colors.muted,
                                    fontSize: 11,
                                  )),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded,
                            color: context.colors.green, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _clientStatCard(
                      icon: Icons.local_fire_department_rounded,
                      color: context.colors.yellow,
                      value: '$clientStreak',
                      label: clientStreak == 1 ? 'Día racha' : 'Días racha',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _clientStatCard(
                      icon: Icons.event_available_rounded,
                      color: context.colors.red,
                      value: '$attendance',
                      label: 'Asistencias',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _clientStatCard(
                      icon: Icons.qr_code_rounded,
                      color: context.colors.green,
                      value: '$clientInsideCount',
                      label: 'Dentro ahora',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: context.colors.panel,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: context.colors.red.withValues(alpha: .35),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.qr_code_2_rounded,
                            color: context.colors.red, size: 20),
                        const SizedBox(width: 8),
                        Text('MI QR PERSONAL',
                            style: TextStyle(
                              color: context.colors.red,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            )),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: QrImageView(
                        data: qrCode,
                        size: 180,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      qrCode,
                      style: TextStyle(
                        color: context.colors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(Icons.event_rounded,
                      color: context.colors.blue, size: 18),
                  const SizedBox(width: 8),
                  Text('CLASES DE HOY',
                      style: TextStyle(
                        color: context.colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      )),
                ],
              ),
              const SizedBox(height: 12),
              if (todayClasses.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: context.colors.panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Center(
                    child: Text('No hay clases programadas hoy',
                        style: TextStyle(
                            color: context.colors.muted, fontSize: 12)),
                  ),
                )
              else
                ...todayClasses.map((c) => _classTodayCard(c)),
              const SizedBox(height: 24),
              if (routineName.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.fitness_center_rounded,
                        color: context.colors.red, size: 18),
                    const SizedBox(width: 8),
                    Text('MI RUTINA',
                        style: TextStyle(
                          color: context.colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        )),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: context.colors.panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: context.colors.red.withValues(alpha: .35),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: context.colors.red.withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.fitness_center_rounded,
                            color: context.colors.red, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(routineName,
                            style: TextStyle(
                              color: context.colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            )),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _clientStatCard({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                color: context.colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1,
              )),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.muted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              )),
        ],
      ),
    );
  }

  Widget _classTodayCard(Map<String, dynamic> c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: context.colors.red.withValues(alpha: .35), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: context.colors.red.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: context.colors.red.withValues(alpha: .35)),
            ),
            alignment: Alignment.center,
            child: Text(c['time'].toString(),
                style: TextStyle(
                  color: context.colors.red,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                )),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c['name'].toString(),
                    style: TextStyle(
                      color: context.colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person_rounded,
                        color: context.colors.muted, size: 12),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(c['trainer'].toString(),
                          style: TextStyle(
                              color: context.colors.muted, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.room_rounded,
                        color: context.colors.muted, size: 12),
                    const SizedBox(width: 4),
                    Text(c['room'].toString(),
                        style: TextStyle(
                            color: context.colors.muted, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _clientsPage() {
    final isMobile = MediaQuery.of(context).size.width < 850;
    if (isMobile) return _clientsPageMobile();
    return _clientsPageDesktop();
  }

  Widget _clientsPageMobile() {
    final query = searchController.text.toLowerCase();
    var filtered = members.where((m) {
      return m['name'].toString().toLowerCase().contains(query) ||
          m['phone'].toString().toLowerCase().contains(query);
    }).toList();
    if (clientFilter != 'TODOS') {
      filtered = filtered.where((m) {
        if (clientFilter == 'ACTIVOS') return m['status'] == 'ACTIVO';
        if (clientFilter == 'POR VENCER') {
          return m['status'] == 'POR VENCER';
        }
        if (clientFilter == 'VENCIDOS') return m['status'] == 'VENCIDO';
        if (clientFilter == 'PENDIENTES') {
          return m['status'] == 'PENDIENTE';
        }
        return true;
      }).toList();
    }
    final total = members.length;
    final totalActivos = members.where((m) => m['status'] == 'ACTIVO').length;
    final totalPorVencer =
        members.where((m) => m['status'] == 'POR VENCER').length;
    final totalVencidos = members.where((m) => m['status'] == 'VENCIDO').length;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Clientes',
              style: TextStyle(
                color: context.colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              )),
          const SizedBox(height: 4),
          Text('$total ${total == 1 ? "registrado" : "registrados"}',
              style: TextStyle(color: context.colors.muted, fontSize: 13)),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: addMember,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('NUEVO CLIENTE',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  )),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(children: [
            Expanded(
              child: _clientStatCard(
                icon: Icons.people_alt_rounded,
                color: context.colors.blue,
                value: '$total',
                label: 'Total',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _clientStatCard(
                icon: Icons.check_circle_rounded,
                color: context.colors.green,
                value: '$totalActivos',
                label: 'Activos',
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _clientStatCard(
                icon: Icons.warning_amber_rounded,
                color: context.colors.yellow,
                value: '$totalPorVencer',
                label: 'Por vencer',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _clientStatCard(
                icon: Icons.block_rounded,
                color: context.colors.red,
                value: '$totalVencidos',
                label: 'Vencidos',
              ),
            ),
          ]),
          const SizedBox(height: 22),
          TextField(
            controller: searchController,
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: context.colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Buscar cliente...',
              hintStyle: TextStyle(color: context.colors.muted, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded,
                  color: context.colors.muted, size: 20),
              filled: true,
              fillColor: context.colors.panel,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: context.colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: context.colors.red, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: context.colors.panel,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: context.colors.border),
              ),
              child: Center(
                child: Column(children: [
                  Icon(Icons.search_off_rounded,
                      color: context.colors.muted, size: 40),
                  const SizedBox(height: 12),
                  Text('Sin resultados',
                      style: TextStyle(
                        color: context.colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      )),
                ]),
              ),
            )
          else
            ...filtered.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _clientRowMobile(m),
                )),
        ],
      ),
    );
  }

  Widget _clientRowMobile(Map<String, dynamic> m) {
    final status = m['status'].toString();
    Color color = context.colors.green;
    if (status == 'POR VENCER') color = context.colors.yellow;
    if (status == 'VENCIDO') color = context.colors.red;
    if (status == 'PENDIENTE') color = context.colors.red;
    final name = m['name'].toString();
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    final phone = m['phone'].toString();
    final plan = m['plan'].toString();
    final expiry = m['expiry'].toString();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => showClientDetail(m),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: Text(initial,
                    style: TextStyle(
                      color: color,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    )),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(name,
                            style: TextStyle(
                              color: context.colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: color.withValues(alpha: .40)),
                        ),
                        child: Text(status,
                            style: TextStyle(
                              color: color,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            )),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text(phone,
                        style: TextStyle(
                            color: context.colors.muted, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('$plan · vence $expiry',
                        style: TextStyle(
                            color: context.colors.muted, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              SizedBox(
                width: 32,
                height: 32,
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.more_vert_rounded,
                      color: context.colors.muted, size: 20),
                  color: context.colors.panel2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: context.colors.border),
                  ),
                  onSelected: (value) {
                    if (value == 'edit') editMember(m);
                    if (value == 'delete') deleteMember(m);
                    if (value == 'view') showClientDetail(m);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem<String>(
                      value: 'view',
                      child: Row(children: [
                        Icon(Icons.person_rounded,
                            color: context.colors.green, size: 18),
                        const SizedBox(width: 10),
                        Text('Ver perfil',
                            style: TextStyle(color: context.colors.white)),
                      ]),
                    ),
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_rounded,
                            color: context.colors.yellow, size: 18),
                        const SizedBox(width: 10),
                        Text('Editar',
                            style: TextStyle(color: context.colors.white)),
                      ]),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_rounded,
                            color: context.colors.red, size: 18),
                        const SizedBox(width: 10),
                        Text('Eliminar',
                            style: TextStyle(color: context.colors.red)),
                      ]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _clientsPageDesktop() {
    final query = searchController.text.toLowerCase();
    var filtered = members.where((m) {
      return m['name'].toString().toLowerCase().contains(query) ||
          m['phone'].toString().toLowerCase().contains(query);
    }).toList();
    if (clientFilter != 'TODOS') {
      filtered = filtered.where((m) {
        if (clientFilter == 'ACTIVOS') return m['status'] == 'ACTIVO';
        if (clientFilter == 'POR VENCER') {
          return m['status'] == 'POR VENCER';
        }
        if (clientFilter == 'VENCIDOS') return m['status'] == 'VENCIDO';
        if (clientFilter == 'PENDIENTES') {
          return m['status'] == 'PENDIENTE';
        }
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
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CLIENTES',
                      style: TextStyle(
                        color: context.colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      )),
                  const SizedBox(height: 6),
                  Text('Gestión completa de tus clientes',
                      style:
                          TextStyle(color: context.colors.muted, fontSize: 13)),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: addMember,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('NUEVO CLIENTE',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  )),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.red,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13)),
              ),
            ),
          ]),
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
                  Icons.people_alt_rounded, context.colors.blue,
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
                  Icons.check_circle_rounded, context.colors.green,
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
                  Icons.warning_amber_rounded, context.colors.yellow,
                  trend: '+3.2%',
                  subtitle: 'próximos 7 días',
                  chartData: const [0.3, 0.4, 0.35, 0.5, 0.45, 0.55, 0.5, 0.6]),
              _metric('VENCIDOS', totalVencidos.toString(), Icons.block_rounded,
                  context.colors.red,
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
                  style: TextStyle(color: context.colors.white),
                  decoration: _inputDecoration(
                      context, 'Buscar por nombre o teléfono',
                      prefixIcon: Icons.search_rounded),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  _filterChip('TODOS'),
                  const SizedBox(width: 8),
                  _filterChip('PENDIENTES'),
                  const SizedBox(width: 8),
                  _filterChip('ACTIVOS'),
                  const SizedBox(width: 8),
                  _filterChip('POR VENCER'),
                  const SizedBox(width: 8),
                  _filterChip('VENCIDOS'),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (filtered.isEmpty)
            _card(
              title: 'SIN RESULTADOS',
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Center(
                  child: Text('No se encontraron clientes con esos filtros.',
                      style: TextStyle(color: context.colors.muted)),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () => setState(() => clientFilter = label),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? context.colors.red.withValues(alpha: .15)
                  : context.colors.panel2,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: selected
                    ? context.colors.red.withValues(alpha: .45)
                    : context.colors.border,
              ),
            ),
            child: Center(
              child: Text(label,
                  style: TextStyle(
                    color: selected ? context.colors.red : context.colors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  )),
            ),
          ),
        ),
      ),
    );
  }

  Widget _clientRow(Map<String, dynamic> m) {
    final status = m['status'].toString();
    Color color = context.colors.green;
    if (status == 'POR VENCER') color = context.colors.yellow;
    if (status == 'VENCIDO') color = context.colors.red;
    if (status == 'PENDIENTE') color = context.colors.red;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => showClientDetail(m),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.colors.panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                    m['name'].toString().isEmpty
                        ? '?'
                        : m['name'].toString().substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    )),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(m['name'].toString(),
                          style: TextStyle(
                            color: context.colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          )),
                      const SizedBox(width: 10),
                      _statusChip(status, color),
                    ]),
                    const SizedBox(height: 4),
                    Text('${m['phone']} · ${m['plan']} · vence ${m['expiry']}',
                        style: TextStyle(
                            color: context.colors.muted, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                        'Pagos: ${m['payments']} · Total: ${formatPrice((m['totalPaid'] as num).toDouble())}',
                        style: TextStyle(
                          color: context.colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => editMember(m),
                icon: Icon(Icons.edit_rounded,
                    color: context.colors.yellow, size: 20),
                tooltip: 'Editar',
              ),
              IconButton(
                onPressed: () => deleteMember(m),
                icon: Icon(Icons.delete_rounded,
                    color: context.colors.red, size: 20),
                tooltip: 'Eliminar',
              ),
              IconButton(
                onPressed: () =>
                    openGymWhatsApp(clientName: m['name']?.toString()),
                icon: FaIcon(FontAwesomeIcons.whatsapp,
                    color: context.colors.green, size: 20),
                tooltip: 'WhatsApp gym',
              ),
              IconButton(
                onPressed: () => showClientDetail(m),
                icon: Icon(Icons.arrow_forward_ios_rounded,
                    color: context.colors.muted, size: 16),
                tooltip: 'Ver detalle',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _qrCenter() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ACCESO QR',
                      style: TextStyle(
                        color: context.colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      )),
                  const SizedBox(height: 6),
                  Text('Genera y administra el código de acceso del gimnasio',
                      style:
                          TextStyle(color: context.colors.muted, fontSize: 13)),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: generateGymQr,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('REGENERAR QR',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  )),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.red,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13)),
              ),
            ),
          ]),
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
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: context.colors.green.withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color:
                                  context.colors.green.withValues(alpha: .35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: context.colors.green,
                                  shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text(qrTimeLeft,
                                style: TextStyle(
                                  color: context.colors.green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                )),
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
                                color:
                                    context.colors.green.withValues(alpha: .20),
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
                          color: context.colors.panel2,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: context.colors.border),
                        ),
                        child: Column(children: [
                          Text('CÓDIGO DEL DÍA',
                              style: TextStyle(
                                color: context.colors.muted,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              )),
                          const SizedBox(height: 6),
                          Text(qrToken.isEmpty ? 'Generando...' : qrToken,
                              style: TextStyle(
                                color: context.colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              )),
                        ]),
                      ),
                      const SizedBox(height: 20),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: downloadQrAsPng,
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: const Text('DESCARGAR PNG',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                )),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: context.colors.white,
                              side: BorderSide(color: context.colors.border),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: shareQrPng,
                            icon: const Icon(Icons.share_rounded, size: 18),
                            label: const Text('COMPARTIR',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                )),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13)),
                            ),
                          ),
                        ),
                      ]),
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
                      title: 'MODO DE RENOVACIÓN',
                      child: Column(
                        children: [
                          _modeOption(
                            'DIARIO',
                            'Se regenera cada día',
                            Icons.calendar_today_rounded,
                            context.colors.red,
                          ),
                          const SizedBox(height: 8),
                          _modeOption(
                            'SEMANAL',
                            'Se regenera cada semana',
                            Icons.date_range_rounded,
                            context.colors.red,
                          ),
                          const SizedBox(height: 8),
                          _modeOption(
                            'FIJO',
                            'No se regenera',
                            Icons.lock_rounded,
                            context.colors.red,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _card(
                      title: 'INFO',
                      child: Column(children: [
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
                      ]),
                    ),
                    const SizedBox(height: 16),
                    _button('RESET AFORO', context.colors.red, resetAforo),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: _accessStat(
                  'DENTRO AHORA', inside.toString(), context.colors.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _accessStat(
                  'ENTRADAS HOY',
                  activities
                      .where((a) => a['type'] == 'ENTRADA')
                      .length
                      .toString(),
                  context.colors.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _accessStat(
                  'BLOQUEADOS',
                  activities
                      .where((a) => a['type'] == 'BLOQUEADO')
                      .length
                      .toString(),
                  context.colors.red),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _accessStat(
                  'SALIDAS',
                  activities
                      .where((a) => a['type'] == 'SALIDA')
                      .length
                      .toString(),
                  context.colors.yellow),
            ),
          ]),
          const SizedBox(height: 24),
          _card(
            title: 'ACTIVIDAD DE ACCESO EN VIVO',
            action: 'VER TODO',
            onAction: showActivity,
            child: activities.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text('Sin accesos registrados',
                          style: TextStyle(color: context.colors.muted)),
                    ),
                  )
                : Column(
                    children: activities.take(8).map((log) {
                      final authorized = log['type'] != 'BLOQUEADO';
                      final color = authorized
                          ? context.colors.green
                          : context.colors.red;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: context.colors.panel2,
                          borderRadius: BorderRadius.circular(13),
                          border:
                              Border.all(color: color.withValues(alpha: .20)),
                        ),
                        child: Row(children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: .12),
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
                                Text(log['name'].toString(),
                                    style: TextStyle(
                                      color: context.colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    )),
                                const SizedBox(height: 2),
                                Text(log['type'].toString(),
                                    style: TextStyle(
                                      color: authorized
                                          ? context.colors.muted
                                          : color,
                                      fontSize: 11,
                                    )),
                              ],
                            ),
                          ),
                          Text(log['time'].toString(),
                              style: TextStyle(
                                color: context.colors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              )),
                        ]),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: _button(
                  'ESCANEAR CLIENTE', context.colors.red, showAccessScanner),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _button(
                  'REGISTRAR SALIDA', context.colors.green, registerExit),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _qrCenterMobile() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ACCESO QR',
              style: TextStyle(
                color: context.colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              )),
          const SizedBox(height: 6),
          Text('Genera el código de acceso del gimnasio',
              style: TextStyle(color: context.colors.muted, fontSize: 12)),
          const SizedBox(height: 20),
          _button('REGENERAR QR', context.colors.red, generateGymQr),
          const SizedBox(height: 20),
          _card(
            title: 'QR DEL GIMNASIO',
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.colors.green.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(qrTimeLeft,
                      style: TextStyle(
                        color: context.colors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      )),
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
                Text(qrToken.isEmpty ? 'Generando...' : qrToken,
                    style: TextStyle(
                      color: context.colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    )),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: downloadQrAsPng,
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('DESCARGAR',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 10)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.colors.white,
                        side: BorderSide(color: context.colors.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: shareQrPng,
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text('COMPARTIR',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 10)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _card(
            title: 'MODO',
            child: Column(children: [
              _modeOption('DIARIO', 'Cada día', Icons.calendar_today_rounded,
                  context.colors.red),
              const SizedBox(height: 8),
              _modeOption('SEMANAL', 'Cada semana', Icons.date_range_rounded,
                  context.colors.red),
              const SizedBox(height: 8),
              _modeOption(
                  'FIJO', 'Nunca', Icons.lock_rounded, context.colors.red),
            ]),
          ),
          const SizedBox(height: 20),
          _card(
            title: 'RESUMEN DEL DÍA',
            child: Column(children: [
              _accessStat(
                  'DENTRO AHORA', inside.toString(), context.colors.green),
              const SizedBox(height: 12),
              _accessStat(
                  'ENTRADAS HOY',
                  activities
                      .where((a) => a['type'] == 'ENTRADA')
                      .length
                      .toString(),
                  context.colors.blue),
              const SizedBox(height: 12),
              _accessStat(
                  'BLOQUEADOS',
                  activities
                      .where((a) => a['type'] == 'BLOQUEADO')
                      .length
                      .toString(),
                  context.colors.red),
              const SizedBox(height: 12),
              _accessStat(
                  'SALIDAS',
                  activities
                      .where((a) => a['type'] == 'SALIDA')
                      .length
                      .toString(),
                  context.colors.yellow),
            ]),
          ),
          const SizedBox(height: 20),
          _button('RESET AFORO', context.colors.red, resetAforo),
          const SizedBox(height: 20),
          _button('ESCANEAR CLIENTE', context.colors.red, showAccessScanner),
          const SizedBox(height: 10),
          _button('REGISTRAR SALIDA', context.colors.green, registerExit),
        ],
      ),
    );
  }

  Widget _plansPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PLANES Y MEMBRESÍAS',
                      style: TextStyle(
                        color: context.colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      )),
                  const SizedBox(height: 6),
                  Text('Administra los planes disponibles del gimnasio',
                      style:
                          TextStyle(color: context.colors.muted, fontSize: 13)),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: addPlan,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('NUEVO PLAN',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  )),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.red,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13)),
              ),
            ),
          ]),
          const SizedBox(height: 28),
          if (plans.isEmpty)
            _card(
              title: 'SIN PLANES',
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Text('Crea tu primer plan con el botón NUEVO PLAN',
                      style: TextStyle(color: context.colors.muted)),
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
                return _planCardPro(plan: p, price: price);
              },
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
          Row(children: [
            Expanded(
              child: Text('PLANES',
                  style: TextStyle(
                    color: context.colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  )),
            ),
            IconButton(
              onPressed: addPlan,
              icon: Icon(Icons.add_circle_rounded,
                  color: context.colors.red, size: 30),
            ),
          ]),
          const SizedBox(height: 15),
          if (plans.isEmpty)
            _card(
              title: 'SIN PLANES',
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Center(
                  child: Text('Crea tu primer plan',
                      style: TextStyle(color: context.colors.muted)),
                ),
              ),
            )
          else
            ...plans.map((p) {
              final price = (p['price'] as num).toDouble();
              final name = p['name'].toString();
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.colors.panel,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: context.colors.red.withValues(alpha: .35),
                      width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: context.colors.red.withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.card_membership_rounded,
                            color: context.colors.red, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(name.toUpperCase(),
                            style: TextStyle(
                              color: context.colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            )),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert_rounded,
                            color: context.colors.muted, size: 20),
                        color: context.colors.panel2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: context.colors.border),
                        ),
                        onSelected: (value) {
                          if (value == 'edit') {
                            editPlan(p);
                          } else if (value == 'delete') {
                            deletePlan(p);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: Row(children: [
                              Icon(Icons.edit_rounded,
                                  color: context.colors.yellow, size: 18),
                              const SizedBox(width: 10),
                              Text('Editar',
                                  style:
                                      TextStyle(color: context.colors.white)),
                            ]),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(children: [
                              Icon(Icons.delete_rounded,
                                  color: context.colors.red, size: 18),
                              const SizedBox(width: 10),
                              Text('Eliminar',
                                  style:
                                      TextStyle(color: context.colors.white)),
                            ]),
                          ),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 16),
                    Text(formatPrice(price),
                        style: TextStyle(
                          color: context.colors.red,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        )),
                    if (showConversion) ...[
                      const SizedBox(height: 4),
                      Text(formatPriceSecondary(price),
                          style: TextStyle(
                            color: context.colors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                    const SizedBox(height: 16),
                    Text('${p['days']} días · ${p['access']}',
                        style: TextStyle(
                            color: context.colors.muted, fontSize: 12)),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => sharePlan(p, price),
                        icon: const Icon(Icons.share_rounded, size: 16),
                        label: const Text('COMPARTIR PLAN',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            )),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
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

  Widget _planCardPro({
    required Map<String, dynamic> plan,
    required double price,
  }) {
    final name = plan['name'].toString();
    return Container(
      decoration: BoxDecoration(
        color: context.colors.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: context.colors.red.withValues(alpha: .35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: context.colors.red.withValues(alpha: .08),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: context.colors.red.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: context.colors.red.withValues(alpha: .35)),
                ),
                child: Icon(Icons.card_membership_rounded,
                    color: context.colors.red, size: 26),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded,
                    color: context.colors.muted, size: 20),
                color: context.colors.panel2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: context.colors.border),
                ),
                onSelected: (value) {
                  if (value == 'edit') {
                    editPlan(plan);
                  } else if (value == 'delete') {
                    deletePlan(plan);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_rounded,
                          color: context.colors.yellow, size: 18),
                      const SizedBox(width: 10),
                      Text('Editar',
                          style: TextStyle(color: context.colors.white)),
                    ]),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_rounded,
                          color: context.colors.red, size: 18),
                      const SizedBox(width: 10),
                      Text('Eliminar',
                          style: TextStyle(color: context.colors.white)),
                    ]),
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 20),
            Text(name.toUpperCase(),
                style: TextStyle(
                  color: context.colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                )),
            const SizedBox(height: 16),
            Text(formatPrice(price),
                style: TextStyle(
                  color: context.colors.red,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                )),
            if (showConversion) ...[
              const SizedBox(height: 4),
              Text(formatPriceSecondary(price),
                  style: TextStyle(
                    color: context.colors.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  )),
            ],
            const SizedBox(height: 20),
            Container(
                height: 1, color: context.colors.white.withValues(alpha: .06)),
            const SizedBox(height: 16),
            _featureItem(
                '${plan['days']} días de vigencia', true, context.colors.red),
            const SizedBox(height: 10),
            _featureItem(plan['access'].toString(), true, context.colors.red),
            const SizedBox(height: 10),
            _featureItem('Acceso a todas las áreas', true, context.colors.red),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => sharePlan(plan, price),
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('COMPARTIR PLAN',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    )),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureItem(String text, bool included, Color color) {
    return Row(children: [
      Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color:
              included ? color.withValues(alpha: .15) : context.colors.panel2,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(
          included ? Icons.check_rounded : Icons.close_rounded,
          color: included ? color : context.colors.muted,
          size: 14,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(text,
            style: TextStyle(
              color: included ? context.colors.white : context.colors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            )),
      ),
    ]);
  }

  Widget _financePage() {
    final isMobile = MediaQuery.of(context).size.width < 850;
    if (isMobile) return _financePageMobile();
    return _financePageDesktop();
  }

  Widget _financePageMobile() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Finanzas',
              style: TextStyle(
                color: context.colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              )),
          const SizedBox(height: 4),
          Text('Control financiero del gimnasio',
              style: TextStyle(color: context.colors.muted, fontSize: 13)),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: newPayment,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('REGISTRAR PAGO',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  )),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.green,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 22),
          _financeBigCard(
            title: 'INGRESOS',
            value: formatPrice(totalIncome),
            color: context.colors.green,
          ),
          const SizedBox(height: 12),
          _financeBigCard(
            title: 'EGRESOS',
            value: formatPrice(totalExpense),
            color: context.colors.red,
          ),
          const SizedBox(height: 12),
          _financeBigCard(
            title: 'BALANCE',
            value: formatPrice(balance),
            color: context.colors.blue,
          ),
          const SizedBox(height: 20),
          _card(
            title: 'MÉTODOS DE PAGO',
            child: SizedBox(height: 180, child: _donutChart()),
          ),
          const SizedBox(height: 20),
          _card(
            title: 'TRANSACCIONES',
            child: filteredTransactions.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(30),
                    child: Center(
                      child: Text('Sin transacciones',
                          style: TextStyle(color: context.colors.muted)),
                    ),
                  )
                : Column(
                    children: filteredTransactions.take(10).map((t) {
                      final isIncome = t['type'] == 'INGRESO';
                      final amount = (t['amount'] as num).toDouble();
                      final color =
                          isIncome ? context.colors.green : context.colors.red;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isIncome
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                              color: color,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t['name'].toString(),
                                    style: TextStyle(
                                      color: context.colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                Text(t['date'].toString(),
                                    style: TextStyle(
                                      color: context.colors.muted,
                                      fontSize: 10,
                                    )),
                              ],
                            ),
                          ),
                          Text(formatPrice(amount.abs()),
                              style: TextStyle(
                                color: color,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              )),
                        ]),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _financePageDesktop() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('FINANZAS',
                      style: TextStyle(
                        color: context.colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      )),
                  const SizedBox(height: 6),
                  Text('Control financiero completo del gimnasio',
                      style:
                          TextStyle(color: context.colors.muted, fontSize: 13)),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: newPayment,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('NUEVO PAGO',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  )),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.green,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13)),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          Row(children: [
            _periodChip('HOY'),
            const SizedBox(width: 8),
            _periodChip('SEMANA'),
            const SizedBox(width: 8),
            _periodChip('MES'),
            const SizedBox(width: 8),
            _periodChip('AÑO'),
            const SizedBox(width: 8),
            _periodChip('TODO'),
          ]),
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
                  Icons.trending_up_rounded, context.colors.green,
                  trend: '+14.2%',
                  subtitle: 'vs mes anterior',
                  chartData: const [0.4, 0.5, 0.6, 0.55, 0.7, 0.8, 0.9, 1.0]),
              _metric('EGRESOS', formatPrice(totalExpense),
                  Icons.trending_down_rounded, context.colors.red,
                  trend: '-3.1%',
                  subtitle: 'vs mes anterior',
                  chartData: const [0.9, 0.8, 0.85, 0.7, 0.65, 0.6, 0.55, 0.5]),
              _metric('BALANCE', formatPrice(balance),
                  Icons.account_balance_wallet_rounded, context.colors.blue,
                  trend: '+11.8%',
                  subtitle: 'ganancia neta',
                  chartData: const [0.3, 0.4, 0.5, 0.55, 0.65, 0.7, 0.85, 1.0]),
              _metric('MRR', formatPrice(mrr), Icons.autorenew_rounded,
                  context.colors.green,
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
                  Icons.favorite_rounded, context.colors.yellow,
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
              _metric('LTV', formatPrice(ltv), Icons.diamond_rounded,
                  context.colors.blue,
                  trend: '+8.4%',
                  subtitle: 'valor por cliente',
                  chartData: const [0.4, 0.5, 0.6, 0.65, 0.7, 0.8, 0.9, 1.0]),
            ],
          ),
          const SizedBox(height: 24),
          _card(
            title: 'INGRESOS ÚLTIMOS 12 MESES',
            child: SizedBox(height: 280, child: _lineChart()),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _card(
                  title: 'INGRESOS VS EGRESOS (4 SEMANAS)',
                  child: SizedBox(height: 260, child: _barChart()),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                flex: 2,
                child: _card(
                  title: 'MÉTODOS DE PAGO',
                  child: SizedBox(
                    height: 260,
                    child: Row(children: [
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.key,
                                        style: TextStyle(
                                          color: context.colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        )),
                                    Text(formatPrice(e.value),
                                        style: TextStyle(
                                          color: color,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        )),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ]),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _card(
            title: 'TRANSACCIONES RECIENTES',
            child: filteredTransactions.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text('Aún no hay transacciones',
                          style: TextStyle(color: context.colors.muted)),
                    ),
                  )
                : Column(
                    children: filteredTransactions.take(10).map((t) {
                      final isIncome = t['type'] == 'INGRESO';
                      final amount = (t['amount'] as num).toDouble();
                      final color =
                          isIncome ? context.colors.green : context.colors.red;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: context.colors.panel2,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: context.colors.border),
                        ),
                        child: Row(children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: .12),
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
                                Text(t['name'].toString(),
                                    style: TextStyle(
                                      color: context.colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    )),
                                const SizedBox(height: 2),
                                Text('${t['concept']} · ${t['method']}',
                                    style: TextStyle(
                                      color: context.colors.muted,
                                      fontSize: 11,
                                    )),
                              ],
                            ),
                          ),
                          Text(formatPrice(amount.abs()),
                              style: TextStyle(
                                color: color,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              )),
                        ]),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _financeBigCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                color: context.colors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              )),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                color: context.colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Color _methodColor(String method) {
    switch (method) {
      case 'TARJETA':
        return context.colors.blue;
      case 'EFECTIVO':
        return context.colors.green;
      case 'TRANSFERENCIA':
        return context.colors.yellow;
      default:
        return context.colors.red;
    }
  }

  Widget _periodChip(String label) {
    final selected = financePeriod == label;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () => setState(() => financePeriod = label),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? context.colors.green.withValues(alpha: .15)
                  : context.colors.panel2,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: selected
                    ? context.colors.green.withValues(alpha: .45)
                    : context.colors.border,
              ),
            ),
            child: Center(
              child: Text(label,
                  style: TextStyle(
                    color:
                        selected ? context.colors.green : context.colors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  )),
            ),
          ),
        ),
      ),
    );
  }

  Widget _lineChart() {
    final maxVal = monthlyIncome.isEmpty
        ? 0.0
        : monthlyIncome.reduce((a, b) => a > b ? a : b);
    final maxY = maxVal == 0 ? 100.0 : maxVal * 1.2;
    return LineChart(LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY / 5,
        getDrawingHorizontalLine: (value) =>
            FlLine(color: context.colors.border, strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 50,
            interval: maxY / 5,
            getTitlesWidget: (value, meta) {
              return Text('\$${(value / 1000).toStringAsFixed(0)}k',
                  style: TextStyle(color: context.colors.muted, fontSize: 10));
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
                child: Text(monthLabels[i],
                    style: TextStyle(
                      color: context.colors.muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    )),
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
          spots: List.generate(monthlyIncome.length,
              (i) => FlSpot(i.toDouble(), monthlyIncome[i])),
          isCurved: true,
          color: context.colors.green,
          barWidth: 3,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
              radius: 4,
              color: context.colors.green,
              strokeWidth: 2,
              strokeColor: context.colors.bg,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            color: context.colors.green.withValues(alpha: .15),
          ),
        ),
      ],
    ));
  }

  Widget _barChart() {
    final allValues = [...weeklyIncome, ...weeklyExpense];
    final maxVal =
        allValues.isEmpty ? 0.0 : allValues.reduce((a, b) => a > b ? a : b);
    final maxY = maxVal == 0 ? 100.0 : maxVal * 1.3;
    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxY,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY / 4,
        getDrawingHorizontalLine: (value) =>
            FlLine(color: context.colors.border, strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 46,
            interval: maxY / 4,
            getTitlesWidget: (value, meta) => Text(
              '\$${(value / 1000).toStringAsFixed(1)}k',
              style: TextStyle(color: context.colors.muted, fontSize: 10),
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
                child: Text(labels[i],
                    style: TextStyle(
                      color: context.colors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    )),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      barGroups: List.generate(weeklyIncome.length, (i) {
        return BarChartGroupData(x: i, barRods: [
          BarChartRodData(
            toY: weeklyIncome[i],
            color: context.colors.green,
            width: 14,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
          BarChartRodData(
            toY: weeklyExpense[i],
            color: context.colors.red,
            width: 14,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ]);
      }),
    ));
  }

  Widget _donutChart() {
    final total = paymentMethods.values.fold(0.0, (a, b) => a + b);
    if (total == 0) {
      return Center(
        child: Text('Sin datos',
            style: TextStyle(color: context.colors.muted, fontSize: 12)),
      );
    }
    return PieChart(PieChartData(
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
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        );
      }).toList(),
    ));
  }

  Widget _trainingPage() {
    final tabs = ['RUTINAS', 'EJERCICIOS', 'ENTRENADORES', 'TIPOS', 'HORARIO'];
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          decoration: BoxDecoration(
            color: context.colors.bg,
            border: Border(bottom: BorderSide(color: context.colors.border)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(tabs.length, (i) {
                final active = trainingTab == i;
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(11),
                      onTap: () => setState(() => trainingTab = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: active
                              ? context.colors.red.withValues(alpha: .15)
                              : context.colors.panel,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: active
                                ? context.colors.red.withValues(alpha: .45)
                                : context.colors.border,
                          ),
                        ),
                        child: Text(tabs[i],
                            style: TextStyle(
                              color: active
                                  ? context.colors.red
                                  : context.colors.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            )),
                      ),
                    ),
                  ),
                );
              }),
            ),
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
        return _classTypesTab();
      case 4:
        return _scheduleTab();
      default:
        return _routinesTab();
    }
  }

  Widget _routinesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text('RUTINAS DISPONIBLES',
                style: TextStyle(
                  color: context.colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                )),
          ),
          ElevatedButton.icon(
            onPressed: addRoutine,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('NUEVA RUTINA',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13)),
            ),
          ),
        ]),
        const SizedBox(height: 20),
        if (routines.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Text('Sin rutinas creadas',
                  style: TextStyle(color: context.colors.muted)),
            ),
          )
        else
          ...routines.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.colors.panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: context.colors.red.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.fitness_center_rounded,
                          color: context.colors.red, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r['name'].toString(),
                              style: TextStyle(
                                color: context.colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              )),
                          const SizedBox(height: 3),
                          Text(
                              '${r['level']} · ${r['duration']} min · ${r['exercises']} ej',
                              style: TextStyle(
                                  color: context.colors.muted, fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => showAssignRoutineDialog(r),
                      icon: Icon(Icons.person_add_rounded,
                          color: context.colors.green, size: 20),
                    ),
                    IconButton(
                      onPressed: () => editRoutine(r),
                      icon: Icon(Icons.edit_rounded,
                          color: context.colors.yellow, size: 18),
                    ),
                    IconButton(
                      onPressed: () => deleteRoutine(r),
                      icon: Icon(Icons.delete_rounded,
                          color: context.colors.red, size: 18),
                    ),
                  ]),
                ),
              )),
      ],
    );
  }

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
        Row(children: [
          Expanded(
            child: Text('BIBLIOTECA DE EJERCICIOS',
                style: TextStyle(
                  color: context.colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                )),
          ),
          ElevatedButton.icon(
            onPressed: addExercise,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('NUEVO EJERCICIO',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13)),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: muscles.map((m) {
              final active = exerciseFilter == m;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(11),
                    onTap: () => setState(() => exerciseFilter = m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: active
                            ? context.colors.red.withValues(alpha: .15)
                            : context.colors.panel,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: active
                              ? context.colors.red.withValues(alpha: .45)
                              : context.colors.border,
                        ),
                      ),
                      child: Text(m.toUpperCase(),
                          style: TextStyle(
                            color: active
                                ? context.colors.red
                                : context.colors.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          )),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Text('Sin ejercicios',
                  style: TextStyle(color: context.colors.muted)),
            ),
          )
        else
          ...filtered.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.colors.panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: context.colors.red.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(Icons.fitness_center_rounded,
                          color: context.colors.red, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e['name'].toString(),
                              style: TextStyle(
                                color: context.colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              )),
                          Text('${e['muscle']} · ${e['level']}',
                              style: TextStyle(
                                  color: context.colors.muted, fontSize: 11)),
                        ],
                      ),
                    ),
                    Text('${e['sets']}x${e['reps']} · ${e['weight']}kg',
                        style: TextStyle(
                          color: context.colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        )),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => editExercise(e),
                      icon: Icon(Icons.edit_rounded,
                          color: context.colors.yellow, size: 18),
                    ),
                    IconButton(
                      onPressed: () => deleteExercise(e),
                      icon: Icon(Icons.delete_rounded,
                          color: context.colors.red, size: 18),
                    ),
                  ]),
                ),
              )),
      ],
    );
  }

  Widget _trainersTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text('ENTRENADORES',
                style: TextStyle(
                  color: context.colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                )),
          ),
          ElevatedButton.icon(
            onPressed: addTrainer,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('NUEVO ENTRENADOR',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13)),
            ),
          ),
        ]),
        const SizedBox(height: 20),
        if (trainers.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Text('Sin entrenadores',
                  style: TextStyle(color: context.colors.muted)),
            ),
          )
        else
          ...trainers.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.colors.panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Row(children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: context.colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(t['name'].toString()[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          )),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t['name'].toString(),
                              style: TextStyle(
                                color: context.colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              )),
                          Text('${t['specialty']} · ${t['schedule']}',
                              style: TextStyle(
                                  color: context.colors.muted, fontSize: 11)),
                        ],
                      ),
                    ),
                    Row(children: [
                      Icon(Icons.star_rounded,
                          color: context.colors.yellow, size: 16),
                      const SizedBox(width: 4),
                      Text(t['rating'].toString(),
                          style: TextStyle(
                            color: context.colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          )),
                    ]),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => editTrainer(t),
                      icon: Icon(Icons.edit_rounded,
                          color: context.colors.yellow, size: 18),
                    ),
                    IconButton(
                      onPressed: () => deleteTrainer(t),
                      icon: Icon(Icons.delete_rounded,
                          color: context.colors.red, size: 18),
                    ),
                  ]),
                ),
              )),
      ],
    );
  }

  Widget _classTypesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text('TIPOS DE CLASE',
                style: TextStyle(
                  color: context.colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                )),
          ),
          ElevatedButton.icon(
            onPressed: addClassType,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('NUEVO TIPO',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13)),
            ),
          ),
        ]),
        const SizedBox(height: 20),
        ...classTypes.map((ct) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.colors.panel,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.colors.border),
                ),
                child: Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: context.colors.red.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_iconFromCodePoint(ct['icon'] as int),
                        color: context.colors.red, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(ct['name'].toString().toUpperCase(),
                        style: TextStyle(
                          color: context.colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        )),
                  ),
                  IconButton(
                    onPressed: () => editClassType(ct),
                    icon: Icon(Icons.edit_rounded,
                        color: context.colors.yellow, size: 18),
                  ),
                  IconButton(
                    onPressed: () => deleteClassType(ct),
                    icon: Icon(Icons.delete_rounded,
                        color: context.colors.red, size: 18),
                  ),
                ]),
              ),
            )),
      ],
    );
  }

  Widget _scheduleTab() {
    final days = ['LUNES', 'MARTES', 'MIÉRCOLES', 'JUEVES', 'VIERNES'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text('CALENDARIO SEMANAL',
                style: TextStyle(
                  color: context.colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                )),
          ),
          ElevatedButton.icon(
            onPressed: addClass,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('NUEVA CLASE',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13)),
            ),
          ),
        ]),
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
                  color: context.colors.panel,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            color: context.colors.red, size: 16),
                        const SizedBox(width: 8),
                        Text(day,
                            style: TextStyle(
                              color: context.colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            )),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (dayClasses.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text('Sin clases',
                            style: TextStyle(
                                color: context.colors.muted, fontSize: 11)),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.panel2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: context.colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(classItem['time'].toString(),
                    style: TextStyle(
                      color: context.colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    )),
              ),
              const Spacer(),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => editClass(classItem),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.edit_rounded,
                        color: context.colors.yellow, size: 16),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => deleteClass(classItem),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded,
                        color: context.colors.red, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(classItem['name'].toString(),
              style: TextStyle(
                color: context.colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(classItem['trainer'].toString(),
              style: TextStyle(color: context.colors.muted, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
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
                    backgroundColor: context.colors.border,
                    valueColor: AlwaysStoppedAnimation(context.colors.red),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${classItem['enrolled']}/${classItem['capacity']}',
                  style: TextStyle(color: context.colors.muted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _currencyPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CONFIGURACIÓN',
              style: TextStyle(
                color: context.colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              )),
          const SizedBox(height: 6),
          Text(
              'Personaliza WhatsApp, PIN, monedas y preferencias del gimnasio.',
              style: TextStyle(color: context.colors.muted, fontSize: 13)),
          const SizedBox(height: 26),
          _card(
            title: 'TEMA',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: () => themeController.toggle(),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.colors.panel2,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Row(children: [
                    Icon(
                      themeController.isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      color: context.colors.red,
                      size: 24,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              themeController.isDark
                                  ? 'Modo OSCURO activo'
                                  : 'Modo CLARO activo',
                              style: TextStyle(
                                color: context.colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              )),
                          const SizedBox(height: 3),
                          Text(
                              'Toca para cambiar al modo ${themeController.isDark ? "claro" : "oscuro"}',
                              style: TextStyle(
                                color: context.colors.muted,
                                fontSize: 11,
                              )),
                        ],
                      ),
                    ),
                    Icon(
                      themeController.isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      color: context.colors.red,
                      size: 20,
                    ),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _card(
            title: 'WHATSAPP DEL GIMNASIO',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Número que se abrirá al tocar WhatsApp en un cliente',
                    style:
                        TextStyle(color: context.colors.muted, fontSize: 11)),
                const SizedBox(height: 14),
                _GymPhoneField(
                  initialValue: gymPhone,
                  onChanged: (v) => setState(() => gymPhone = v),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _saveLocalData();
                      if (mounted) {
                        final ctx = context;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text('WhatsApp guardado: $gymPhone'),
                            backgroundColor: ctx.colors.green,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text('GUARDAR NÚMERO',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        )),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _card(
            title: 'PIN DE ADMINISTRADOR',
            child: _ChangePinSection(
              adminPin: adminPin,
              onPinChanged: (newPin) async {
                setState(() => adminPin = newPin);
                await _saveLocalData();
              },
            ),
          ),
          const SizedBox(height: 20),
          _card(
            title: 'MONEDA PRINCIPAL',
            child: Column(
              children: availableCurrencies.map((c) {
                final isSelected = c['code'] == selectedCurrency;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(13),
                      onTap: () async {
                        setState(() => selectedCurrency = c['code']!);
                        await _saveLocalData();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? context.colors.red.withValues(alpha: .13)
                              : context.colors.panel2,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: isSelected
                                ? context.colors.red.withValues(alpha: .45)
                                : context.colors.border,
                          ),
                        ),
                        child: Row(children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: context.colors.red.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(c['symbol']!,
                                  style: TextStyle(
                                    color: context.colors.red,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                  )),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c['code']!,
                                    style: TextStyle(
                                      color: context.colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    )),
                                const SizedBox(height: 2),
                                Text(c['name']!,
                                    style: TextStyle(
                                      color: context.colors.muted,
                                      fontSize: 12,
                                    )),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle_rounded,
                                color: context.colors.red, size: 24),
                        ]),
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
                color: showConversion
                    ? context.colors.green.withValues(alpha: .10)
                    : context.colors.panel2,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: showConversion
                      ? context.colors.green.withValues(alpha: .35)
                      : context.colors.border,
                ),
              ),
              child: Row(children: [
                Icon(
                  showConversion
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: showConversion
                      ? context.colors.green
                      : context.colors.muted,
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
                            color: showConversion
                                ? context.colors.green
                                : context.colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          )),
                      const SizedBox(height: 3),
                      Text(
                          showConversion
                              ? 'Muestra el precio en bolívares debajo del principal'
                              : 'Solo se muestra la moneda principal',
                          style: TextStyle(
                            color: context.colors.muted,
                            fontSize: 11,
                          )),
                    ],
                  ),
                ),
                Switch(
                  value: showConversion,
                  activeColor: context.colors.green,
                  onChanged: (value) async {
                    setState(() => showConversion = value);
                    await _saveLocalData();
                  },
                ),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          _card(
            title: 'TASAS DE CAMBIO',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cuantos Bolívares vale 1 unidad',
                    style:
                        TextStyle(color: context.colors.muted, fontSize: 11)),
                const SizedBox(height: 14),
                _RateField(
                  label: '1 USD = ? Bs (Bolívares)',
                  initialValue: usdToVes,
                  onChanged: (v) async {
                    setState(() => usdToVes = v);
                    await _saveLocalData();
                  },
                ),
                const SizedBox(height: 10),
                _RateField(
                  label: '1 EUR = ? Bs (Bolívares)',
                  initialValue: eurToVes,
                  onChanged: (v) async {
                    setState(() => eurToVes = v);
                    await _saveLocalData();
                  },
                ),
                const SizedBox(height: 10),
                _RateField(
                  label: '1 COP = ? Bs (Bolívares)',
                  initialValue: copToVes,
                  onChanged: (v) async {
                    setState(() => copToVes = v);
                    await _saveLocalData();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _button('LISTO', context.colors.red, () async {
            await _saveLocalData();
            if (!mounted) return;
            _sectionHistory.clear();
            setState(() => _section = 0);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Configuración guardada')),
            );
          }),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _alertsPage() {
    final filtered = filteredAlerts(context);
    final renewals = renewalRequests.where((r) => r['read'] != true).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ALERTAS',
                      style: TextStyle(
                        color: context.colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      )),
                  const SizedBox(height: 6),
                  Text('Centro de notificaciones del gimnasio',
                      style:
                          TextStyle(color: context.colors.muted, fontSize: 13)),
                ],
              ),
            ),
            if ((alertCount(context) + renewals.length) > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: context.colors.red.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: context.colors.red.withValues(alpha: .35)),
                ),
                child: Row(children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: context.colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${alertCount(context) + renewals.length} pendientes',
                      style: TextStyle(
                        color: context.colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      )),
                ]),
              ),
          ]),
          const SizedBox(height: 24),
          if (renewals.isNotEmpty) ...[
            Text('SOLICITUDES DE RENOVACIÓN',
                style: TextStyle(
                  color: context.colors.yellow,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                )),
            const SizedBox(height: 12),
            ...renewals.map((r) => _renewalCard(r)),
            const SizedBox(height: 24),
          ],
          Row(children: [
            _alertFilterChip('TODAS', 'Todas'),
            const SizedBox(width: 8),
            _alertFilterChip('PENDIENTES', 'Pendientes'),
            const SizedBox(width: 8),
            _alertFilterChip('VENCIDAS', 'Vencidas'),
            const SizedBox(width: 8),
            _alertFilterChip('POR VENCER', 'Por vencer'),
            const SizedBox(width: 8),
            _alertFilterChip('INFO', 'Info'),
          ]),
          const SizedBox(height: 24),
          if (filtered.isEmpty && renewals.isEmpty)
            _card(
              title: 'SIN ALERTAS',
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Column(children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: context.colors.green.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(Icons.check_circle_rounded,
                          color: context.colors.green, size: 34),
                    ),
                    const SizedBox(height: 18),
                    Text('Todo en orden',
                        style: TextStyle(
                          color: context.colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        )),
                    const SizedBox(height: 6),
                    Text('No hay alertas pendientes por ahora',
                        style: TextStyle(
                            color: context.colors.muted, fontSize: 12),
                        textAlign: TextAlign.center),
                  ]),
                ),
              ),
            )
          else
            ...filtered.map((alert) => _alertCard(alert)),
        ],
      ),
    );
  }

  Widget _alertsPageMobile() {
    return _alertsPage();
  }

  Widget _renewalCard(Map<String, dynamic> r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: context.colors.yellow.withValues(alpha: .40), width: 1.5),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: context.colors.yellow.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(Icons.autorenew_rounded,
              color: context.colors.yellow, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r['name'].toString(),
                  style: TextStyle(
                    color: context.colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  )),
              const SizedBox(height: 3),
              Text('Plan ${r['plan']} · vence ${r['expiry']}',
                  style: TextStyle(color: context.colors.muted, fontSize: 11)),
            ],
          ),
        ),
        Column(
          children: [
            IconButton(
              onPressed: () {
                setState(() => r['read'] = true);
                _saveLocalData();
              },
              icon: Icon(Icons.close_rounded,
                  color: context.colors.muted, size: 18),
            ),
            IconButton(
              onPressed: () => openGymWhatsApp(
                  customText:
                      'Hola ${r['name']}, recibimos tu solicitud de renovación del plan ${r['plan']}.'),
              icon: Icon(Icons.reply_rounded,
                  color: context.colors.green, size: 18),
            ),
          ],
        ),
      ]),
    );
  }

  Widget _alertCard(Map<String, dynamic> alert) {
    final color = alert['color'] as Color;
    final icon = alert['icon'] as IconData;
    final isPending = alert['action'] == 'approve_client';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .3), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(alert['type'].toString(),
                        style: TextStyle(
                          color: color,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        )),
                  ),
                  const SizedBox(height: 6),
                  Text(alert['title'].toString(),
                      style: TextStyle(
                        color: context.colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(alert['subtitle'].toString(),
                      style:
                          TextStyle(color: context.colors.muted, fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            IconButton(
              onPressed: () => dismissAlert(alert['id'].toString()),
              icon: Icon(Icons.close_rounded,
                  color: context.colors.muted, size: 18),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            if (isPending)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    final member = alert['member'] as Map<String, dynamic>?;
                    if (member != null) approveClient(member);
                  },
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('APROBAR',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      )),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            if (alert['action'] == 'client_detail' && alert['member'] != null)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      showClientDetail(alert['member'] as Map<String, dynamic>),
                  icon: const Icon(Icons.person_rounded, size: 16),
                  label: const Text('VER CLIENTE',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      )),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.white,
                    side: BorderSide(color: context.colors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            if (alert['action'] == 'dashboard')
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _sectionHistory.clear();
                    setState(() => _section = 0);
                  },
                  icon: const Icon(Icons.dashboard_rounded, size: 16),
                  label: const Text('VER DASHBOARD',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      )),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.white,
                    side: BorderSide(color: context.colors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
          ]),
        ],
      ),
    );
  }

  Widget _alertFilterChip(String value, String label) {
    final selected = alertFilter == value;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () => setState(() => alertFilter = value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? context.colors.red.withValues(alpha: .15)
                  : context.colors.panel2,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: selected
                    ? context.colors.red.withValues(alpha: .45)
                    : context.colors.border,
              ),
            ),
            child: Center(
              child: Text(label,
                  style: TextStyle(
                    color: selected ? context.colors.red : context.colors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  )),
            ),
          ),
        ),
      ),
    );
  }

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
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        icon: Icon(icon, size: 20),
        label: Text(text,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
            )),
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
        color: context.colors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const Spacer(),
            if (trend != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(trend,
                    style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    )),
              ),
          ]),
          const SizedBox(height: 10),
          Text(title,
              style: TextStyle(
                color: context.colors.muted,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: .8,
              )),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                color: context.colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1.0,
              )),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(color: context.colors.muted, fontSize: 9)),
          ],
          const SizedBox(height: 8),
          if (chartData != null)
            SizedBox(
              height: 32,
              width: double.infinity,
              child: CustomPaint(
                painter: _MiniChartPainter(data: chartData, color: color),
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
        color: context.colors.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(title,
                  style: TextStyle(
                    color: context.colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  )),
            ),
            if (action != null)
              TextButton(
                onPressed: onAction,
                child: Text(action,
                    style: TextStyle(
                      color: context.colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    )),
              ),
          ]),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _statusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Text(text,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          )),
    );
  }

  Widget _accessStat(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.panel2,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(children: [
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
          child: Text(title,
              style: TextStyle(
                color: context.colors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              )),
        ),
        Text(value,
            style: TextStyle(
              color: color,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            )),
      ]),
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
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        ),
        child: Text(text,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: .5,
            )),
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
      style: TextStyle(color: context.colors.white),
      decoration: _inputDecoration(context, label),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext ctx,
    String label, {
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: ctx.colors.muted),
      prefixIcon:
          prefixIcon == null ? null : Icon(prefixIcon, color: ctx.colors.muted),
      filled: true,
      fillColor: ctx.colors.panel2,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: ctx.colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: ctx.colors.red, width: 1.5),
      ),
    );
  }

  Widget _dialog({
    required String title,
    required Widget child,
    Color? accent,
  }) {
    return Builder(
      builder: (ctx) {
        final ac = accent ?? ctx.colors.red;
        return Dialog(
          backgroundColor: ctx.colors.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: ctx.colors.border),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Container(
                      width: 9,
                      height: 30,
                      decoration: BoxDecoration(
                        color: ac,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(title,
                          style: TextStyle(
                            color: ctx.colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          )),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(Icons.close_rounded, color: ctx.colors.muted),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  child,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _modeOption(
    String mode,
    String description,
    IconData icon,
    Color color,
  ) {
    final isSelected = qrMode == mode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () async {
          setState(() => qrMode = mode);
          generateGymQr();
          await _saveLocalData();
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: .15)
                : context.colors.panel2,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: .45)
                  : context.colors.border,
            ),
          ),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mode,
                      style: TextStyle(
                        color: isSelected
                            ? context.colors.white
                            : context.colors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      )),
                  const SizedBox(height: 2),
                  Text(description,
                      style: TextStyle(
                        color: context.colors.muted,
                        fontSize: 10,
                      )),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 20),
          ]),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(children: [
      Expanded(
        child: Text(label,
            style: TextStyle(
              color: context.colors.muted,
              fontSize: 11,
            )),
      ),
      Text(value,
          style: TextStyle(
            color: context.colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          )),
    ]);
  }

  void showClientDetail(Map<String, dynamic> member) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _ClientProfilePage(
        member: member,
        formatPrice: formatPrice,
        onEdit: () => editMember(member),
        onDelete: () => deleteMember(member),
        transactions: transactions,
        onWhatsApp: () =>
            openGymWhatsApp(clientName: member['name']?.toString()),
      ),
    ));
  }

  void showActivity() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return _dialog(
          title: 'ACTIVIDAD RECIENTE',
          child: SizedBox(
            width: 560,
            child: ListView(
              shrinkWrap: true,
              children: activities.isEmpty
                  ? [
                      Padding(
                        padding: const EdgeInsets.all(30),
                        child: Center(
                          child: Text('Sin actividad reciente',
                              style:
                                  TextStyle(color: dialogContext.colors.muted)),
                        ),
                      ),
                    ]
                  : activities.map((a) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          Icon(Icons.bolt_rounded,
                              color: dialogContext.colors.yellow, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(a['name'] ?? '',
                                style: TextStyle(
                                    color: dialogContext.colors.white,
                                    fontSize: 13)),
                          ),
                          Text(a['type'] ?? '',
                              style: TextStyle(
                                  color: dialogContext.colors.muted,
                                  fontSize: 11)),
                          const SizedBox(width: 12),
                          Text(a['time'] ?? '',
                              style: TextStyle(
                                  color: dialogContext.colors.muted,
                                  fontSize: 11)),
                        ]),
                      );
                    }).toList(),
            ),
          ),
        );
      },
    );
  }

  void showAccessScanner() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          height: MediaQuery.of(sheetContext).size.height * 0.85,
          decoration: BoxDecoration(
            color: sheetContext.colors.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: sheetContext.colors.muted.withValues(alpha: .4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.qr_code_scanner_rounded,
                        color: sheetContext.colors.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'ESCANEAR CLIENTE',
                        style: TextStyle(
                          color: sheetContext.colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: Icon(Icons.close_rounded,
                          color: sheetContext.colors.muted),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: MobileScanner(
                    onDetect: (capture) async {
                      final barcodes = capture.barcodes;
                      if (barcodes.isEmpty) return;
                      final code = barcodes.first.rawValue;
                      if (code == null || code.isEmpty) return;
                      Navigator.pop(sheetContext);
                      await _processClientQrScan(code);
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Apunta al QR personal del cliente',
                  style: TextStyle(
                    color: sheetContext.colors.muted,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _processClientQrScan(String code) async {
    Map<String, dynamic>? found;
    for (final m in members) {
      if (m['qrCode'].toString() == code) {
        found = m;
        break;
      }
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (found == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('❌ Código no reconocido'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final status = found['status'].toString().toUpperCase();
    final memberName = found['name'].toString();
    final memberId = found['id'];
    final isBlocked = status != 'ACTIVO';
    String type = 'ENTRADA';
    try {
      final supabase = Supabase.instance.client;
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final startOfDayStr = startOfDay.toIso8601String();
      final todayCheckins = await supabase
          .from('checkins')
          .select()
          .eq('member_id', memberId)
          .gte('created_at', startOfDayStr)
          .order('created_at', ascending: true);
      final lastType = todayCheckins.isNotEmpty
          ? todayCheckins.last['type'].toString().toUpperCase()
          : '';
      type = lastType == 'ENTRADA' ? 'SALIDA' : 'ENTRADA';
      await supabase.from('checkins').insert({
        'member_id': memberId,
        'type': type,
        'authorized': !isBlocked,
        'reason': isBlocked ? 'Membresía $status' : null,
        'registered_by': 'admin',
      });
      await supabase.from('activities').insert({
        'type': isBlocked ? 'BLOQUEADO' : type,
        'name': memberName,
      });
      if (type == 'ENTRADA' && !isBlocked) {
        final attendance = (found['attendance'] as num?)?.toInt() ?? 0;
        await supabase.from('members').update({
          'attendance': attendance + 1,
          'last_visit': _formatDate(DateTime.now()),
        }).eq('id', memberId);
        if (mounted) {
          setState(() {
            found!['attendance'] = attendance + 1;
            found['lastVisit'] = _formatDate(DateTime.now());
            inside++;
            clientInsideCount++;
          });
        }
      } else if (type == 'SALIDA') {
        if (mounted) {
          setState(() {
            if (clientInsideCount > 0) clientInsideCount--;
          });
        }
      }
      if (mounted) addActivity(isBlocked ? 'BLOQUEADO' : type, memberName);
      await loadActivities();
      await loadCheckins();
      await _saveLocalData();
      if (!mounted) return;
      await _showAccessOverlay(
        success: !isBlocked,
        title: isBlocked ? 'ACCESO DENEGADO' : 'ACCESO PERMITIDO',
        subtitle: isBlocked
            ? 'Membresía $status. Contacta al gym.'
            : type == 'ENTRADA'
                ? '¡Bienvenido al gimnasio!'
                : '¡Hasta pronto!',
        name: memberName,
        status: status,
        type: type,
      );
    } catch (e) {
      debugPrint('❌ Error procesando QR admin: $e');
      if (mounted) {
        await _showAccessOverlay(
          success: false,
          title: 'ERROR DE CONEXIÓN',
          subtitle: 'No se pudo registrar. Intenta de nuevo.',
          name: memberName,
          status: 'ERROR',
        );
      }
    }
  }

  void registerExit() {
    if (inside <= 0) return;
    setState(() => inside--);
    addActivity('SALIDA', 'Acceso registrado');
    _saveLocalData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Salida registrada correctamente')),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      generateGymQr();
      await _loadLocalData();
      if (mounted) setState(() => loadingData = false);
      _syncWithSupabase();
    });
  }

  @override
  void dispose() {
    _aforoTimer?.cancel();
    searchController.dispose();
    pinController.dispose();
    clientCedulaController.dispose();
    regNameController.dispose();
    regCedulaController.dispose();
    regPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 850;
    if (currentRole == UserRole.none) return _loginScreen();
    if (currentRole == UserRole.client) return _clientHome();
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.colors.bg,
      drawer: isMobile ? _mobileDrawer() : null,
      body: isMobile ? _mobile() : _desktop(),
    );
  }
}

class _OccupancyPainter extends CustomPainter {
  final double percentage;
  final Color trackColor;
  final Color progressColor;

  _OccupancyPainter({
    required this.percentage,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    final sweepAngle = 2 * math.pi * percentage.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _OccupancyPainter oldDelegate) =>
      oldDelegate.percentage != percentage;
}

class _MiniChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _MiniChartPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: .35),
          color.withValues(alpha: .0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    final path = Path();
    final fillPath = Path();
    final stepX = size.width / (data.length - 1);
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final safeMax = maxVal == 0 ? 1.0 : maxVal;
    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - (data[i] / safeMax) * size.height;
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
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MiniChartPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.color != color;
}

class _RateField extends StatefulWidget {
  final String label;
  final double initialValue;
  final ValueChanged<double> onChanged;

  const _RateField({
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<_RateField> createState() => _RateFieldState();
}

class _RateFieldState extends State<_RateField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue.toString());
  }

  @override
  void didUpdateWidget(covariant _RateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue &&
        _controller.text != widget.initialValue.toString()) {
      _controller.text = widget.initialValue.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: context.colors.white),
      onChanged: (text) {
        final v = double.tryParse(text.replaceAll(',', '.'));
        if (v != null && v > 0) widget.onChanged(v);
      },
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: TextStyle(color: context.colors.muted),
        filled: true,
        fillColor: context.colors.panel2,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: context.colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: context.colors.red, width: 1.5),
        ),
      ),
    );
  }
}

class _GymPhoneField extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;

  const _GymPhoneField({
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<_GymPhoneField> createState() => _GymPhoneFieldState();
}

class _GymPhoneFieldState extends State<_GymPhoneField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _GymPhoneField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue &&
        _controller.text != widget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.phone,
      style: TextStyle(color: context.colors.white),
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: 'Ej: +58 412 1234567',
        labelStyle: TextStyle(color: context.colors.muted),
        prefixIcon: Icon(Icons.phone_rounded, color: context.colors.muted),
        filled: true,
        fillColor: context.colors.panel2,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: context.colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: context.colors.red, width: 1.5),
        ),
      ),
    );
  }
}

class _ChangePinSection extends StatefulWidget {
  final String adminPin;
  final Future<void> Function(String newPin) onPinChanged;

  const _ChangePinSection({
    required this.adminPin,
    required this.onPinChanged,
  });

  @override
  State<_ChangePinSection> createState() => _ChangePinSectionState();
}

class _ChangePinSectionState extends State<_ChangePinSection> {
  final _currentPinCtrl = TextEditingController();
  final _newPinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();

  @override
  void dispose() {
    _currentPinCtrl.dispose();
    _newPinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  Future<void> _updatePin() async {
    final ctx = context;
    final current = _currentPinCtrl.text.trim();
    final newPin = _newPinCtrl.text.trim();
    final confirm = _confirmPinCtrl.text.trim();
    if (current != widget.adminPin) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: const Text('PIN actual incorrecto'),
          backgroundColor: ctx.colors.red,
        ),
      );
      return;
    }
    if (!RegExp(r'^\d{4}$').hasMatch(newPin)) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: const Text('El nuevo PIN debe tener exactamente 4 dígitos'),
          backgroundColor: ctx.colors.yellow,
        ),
      );
      return;
    }
    if (newPin != confirm) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: const Text('Los PIN nuevos no coinciden'),
          backgroundColor: ctx.colors.red,
        ),
      );
      return;
    }
    if (newPin == current) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: const Text('El nuevo PIN debe ser distinto al actual'),
          backgroundColor: ctx.colors.yellow,
        ),
      );
      return;
    }
    await widget.onPinChanged(newPin);
    _currentPinCtrl.clear();
    _newPinCtrl.clear();
    _confirmPinCtrl.clear();
    if (mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: const Text('✅ PIN actualizado correctamente'),
          backgroundColor: ctx.colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cambia el PIN de acceso del administrador.',
          style: TextStyle(color: context.colors.muted, fontSize: 11),
        ),
        const SizedBox(height: 16),
        _pinField(
          controller: _currentPinCtrl,
          label: 'PIN actual',
          icon: Icons.lock_outline_rounded,
        ),
        const SizedBox(height: 10),
        _pinField(
          controller: _newPinCtrl,
          label: 'Nuevo PIN (4 dígitos)',
          icon: Icons.lock_open_rounded,
        ),
        const SizedBox(height: 10),
        _pinField(
          controller: _confirmPinCtrl,
          label: 'Confirmar nuevo PIN',
          icon: Icons.verified_user_rounded,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _updatePin,
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text('ACTUALIZAR PIN',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                )),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.colors.yellow.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: context.colors.yellow.withValues(alpha: .30)),
          ),
          child: Row(children: [
            Icon(Icons.info_outline_rounded,
                color: context.colors.yellow, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Si olvidas el PIN, borra la app o reinstala para resetearlo.',
                style: TextStyle(
                  color: context.colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _pinField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: 4,
      style: TextStyle(
        color: context.colors.white,
        fontSize: 16,
        letterSpacing: 8,
        fontWeight: FontWeight.w900,
      ),
      decoration: InputDecoration(
        counterText: '',
        labelText: label,
        labelStyle: TextStyle(
          color: context.colors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        prefixIcon: Icon(icon, color: context.colors.red, size: 20),
        filled: true,
        fillColor: context.colors.panel2,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.red, width: 2),
        ),
      ),
    );
  }
}

class _ClientProfilePage extends StatelessWidget {
  final Map<String, dynamic> member;
  final String Function(double) formatPrice;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final List<Map<String, dynamic>> transactions;
  final VoidCallback onWhatsApp;

  const _ClientProfilePage({
    required this.member,
    required this.formatPrice,
    required this.onEdit,
    required this.onDelete,
    required this.transactions,
    required this.onWhatsApp,
  });

  Color _statusColor(BuildContext context) {
    final s = member['status'].toString();
    if (s == 'ACTIVO') return context.colors.green;
    if (s == 'POR VENCER') return context.colors.yellow;
    if (s == 'PENDIENTE') return context.colors.red;
    return context.colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final name = member['name'].toString();
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    final payments = (member['payments'] as num?)?.toInt() ?? 0;
    final totalPaid = (member['totalPaid'] as num?)?.toDouble() ?? 0.0;
    final attendance = (member['attendance'] as num?)?.toInt() ?? 0;
    final routineName = member['assignedRoutine']?.toString() ?? '';
    final memberTx =
        transactions.where((t) => t['name'] == name).take(10).toList();
    final statusColor = _statusColor(context);
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back_ios_new_rounded,
                      color: context.colors.white, size: 20),
                ),
                Expanded(
                  child: Text('Perfil del cliente',
                      style: TextStyle(
                        color: context.colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      )),
                ),
                IconButton(
                  onPressed: () => _showActions(context),
                  icon: Icon(Icons.more_horiz_rounded,
                      color: context.colors.white, size: 24),
                ),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: .15),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: statusColor.withValues(alpha: .40),
                                width: 2),
                          ),
                          alignment: Alignment.center,
                          child: Text(initial,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                              )),
                        ),
                        const SizedBox(height: 14),
                        Text(name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: context.colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.3,
                            )),
                        const SizedBox(height: 6),
                        Text(member['phone'].toString(),
                            style: TextStyle(
                              color: context.colors.muted,
                              fontSize: 13,
                            )),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                                color: statusColor.withValues(alpha: .40)),
                          ),
                          child: Text(member['status'].toString(),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              )),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 28),
                    Row(children: [
                      Expanded(
                        child: _miniStatTile(
                          icon: Icons.event_available_rounded,
                          color: context.colors.red,
                          value: '$attendance',
                          label: 'Asistencia',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _miniStatTile(
                          icon: Icons.receipt_long_rounded,
                          color: context.colors.yellow,
                          value: '$payments',
                          label: 'Pagos',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _miniStatTile(
                          icon: Icons.attach_money_rounded,
                          color: context.colors.green,
                          value: formatPrice(totalPaid),
                          label: 'Total',
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    if (routineName.isNotEmpty) ...[
                      _profileCard(
                        title: 'RUTINA ASIGNADA',
                        icon: Icons.fitness_center_rounded,
                        color: context.colors.red,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: context.colors.red.withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color:
                                    context.colors.red.withValues(alpha: .35)),
                          ),
                          child: Row(children: [
                            Icon(Icons.fitness_center_rounded,
                                color: context.colors.red, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(routineName,
                                  style: TextStyle(
                                    color: context.colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  )),
                            ),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _profileCard(
                      title: 'INFORMACIÓN',
                      icon: Icons.info_outline_rounded,
                      color: context.colors.red,
                      child: Column(children: [
                        _infoRowDetail('Plan', member['plan'].toString()),
                        _infoRowDetail('Vence', member['expiry'].toString()),
                        _infoRowDetail(
                            'Miembro desde', member['memberSince'].toString()),
                        _infoRowDetail(
                            'Última visita', member['lastVisit'].toString(),
                            isLast: true),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    _profileCard(
                      title: 'QR DE ACCESO',
                      icon: Icons.qr_code_rounded,
                      color: context.colors.green,
                      child: Column(children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: QrImageView(
                            data: member['qrCode'].toString(),
                            size: 180,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(member['qrCode'].toString(),
                            style: TextStyle(
                              color: context.colors.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                            textAlign: TextAlign.center),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    _profileCard(
                      title: 'HISTORIAL DE PAGOS',
                      icon: Icons.receipt_rounded,
                      color: context.colors.yellow,
                      child: memberTx.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Text('Sin pagos registrados',
                                    style: TextStyle(
                                        color: context.colors.muted,
                                        fontSize: 12)),
                              ),
                            )
                          : Column(
                              children: memberTx
                                  .map((t) => _paymentHistoryRow(t))
                                  .toList(),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: context.colors.bg,
                border: Border(top: BorderSide(color: context.colors.border)),
              ),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Future.microtask(() => onEdit());
                    },
                    icon: Icon(Icons.edit_rounded,
                        color: context.colors.yellow, size: 18),
                    label: Text('EDITAR',
                        style: TextStyle(
                          color: context.colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: .5,
                        )),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: context.colors.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onWhatsApp,
                    icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 18),
                    label: const Text('WHATSAPP',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: .5,
                        )),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: sheetContext.colors.muted.withValues(alpha: .4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading:
                  Icon(Icons.edit_rounded, color: sheetContext.colors.yellow),
              title: Text('Editar miembro',
                  style: TextStyle(
                      color: sheetContext.colors.white,
                      fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.pop(sheetContext);
                Future.microtask(() => onEdit());
              },
            ),
            ListTile(
              leading:
                  Icon(Icons.delete_rounded, color: sheetContext.colors.red),
              title: Text('Eliminar miembro',
                  style: TextStyle(
                      color: sheetContext.colors.red,
                      fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.pop(sheetContext);
                Future.microtask(() => onDelete());
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _miniStatTile({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Builder(builder: (context) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: context.colors.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                color: context.colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                color: context.colors.muted,
                fontSize: 10,
              )),
        ]),
      );
    });
  }

  Widget _profileCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Builder(builder: (context) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.colors.panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: TextStyle(
                    color: context.colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  )),
            ]),
            const SizedBox(height: 16),
            child,
          ],
        ),
      );
    });
  }

  Widget _infoRowDetail(String label, String value, {bool isLast = false}) {
    return Builder(builder: (context) {
      return Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Text(label,
                  style: TextStyle(
                    color: context.colors.muted,
                    fontSize: 12,
                  )),
            ),
            Expanded(
              flex: 6,
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: context.colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  )),
            ),
          ],
        ),
      );
    });
  }

  Widget _paymentHistoryRow(Map<String, dynamic> t) {
    return Builder(builder: (context) {
      final method = t['method'].toString();
      final amount = (t['amount'] as num).toDouble();
      final date = t['date'].toString();
      Color methodColor = context.colors.green;
      IconData methodIcon = Icons.payments_rounded;
      if (method == 'TARJETA') {
        methodColor = context.colors.blue;
        methodIcon = Icons.credit_card_rounded;
      } else if (method == 'TRANSFERENCIA') {
        methodColor = context.colors.yellow;
        methodIcon = Icons.swap_horiz_rounded;
      }
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.panel2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: methodColor.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(methodIcon, color: methodColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(method,
                    style: TextStyle(
                      color: context.colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    )),
                const SizedBox(height: 2),
                Text(date,
                    style:
                        TextStyle(color: context.colors.muted, fontSize: 10)),
              ],
            ),
          ),
          Text(formatPrice(amount),
              style: TextStyle(
                color: context.colors.green,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              )),
        ]),
      );
    });
  }
}

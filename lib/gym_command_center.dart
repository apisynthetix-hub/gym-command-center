// lib/gym_command_center.dart
import 'dart:io' show File;
import 'dart:html' as html;
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
  Timer? _qrRefreshTimer;
  Timer? _summaryTimer;
  int clientStreak = 0;
  List<String> clientCheckinDates = [];
  List<Map<String, dynamic>> insidePeople = [];

  // --- RESUMEN DEL DÍA ---
  int todayEntries = 0;
  int todayExits = 0;
  int todayBlocked = 0;
  double todayIncome = 0.0; // ✅ NUEVO: Caja del día
  List<Map<String, dynamic>> todayEntriesList = [];
  List<Map<String, dynamic>> todayExitsList = [];
  List<Map<String, dynamic>> todayBlockedList = [];

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
  final TextEditingController _capacityController = TextEditingController();

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
  int financeVisibleCount = 12;
  int trainingTab = 0;
  String exerciseFilter = 'TODOS';
  bool loadingData = true;
  bool _qrProcessing = false;

  // ✅ NUEVO: control de historial de resumen
  DateTime summarySelectedDate = DateTime.now();
  bool summaryViewAll = false;
  DateTimeRange accessHistoryRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  String accessHistoryType = 'TODOS';
  bool loadingAccessHistory = false;
  List<Map<String, dynamic>> accessHistory = [];

  // ✅ NUEVO: Variables para el aviso flotante en el Dashboard
  Map<String, dynamic>? lastAccessAlert;
  Timer? _alertTimer;

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

  // ✅ NUEVO HELPER: Formato de hora 12h (ej: 3:38 PM)
  String _fmtTime(DateTime d) {
    final h = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
    final m = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour >= 12 ? 'p. m.' : 'a. m.';
    return '$h:$m $ampm';
  }

  final List<Map<String, dynamic>> members = [
    {
      'id': 'local-demo-1',
      'name': 'Cliente Demo',
      'cedula': '12345678',
      'phone': '+00 000 000000',
      'plan': 'Básico',
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
      'name': 'Básico',
      'price': 29.99,
      'days': 30,
      'access': 'ILIMITADO'
    },
    {
      'id': 'local-p2',
      'name': 'Preferente',
      'price': 49.99,
      'days': 30,
      'access': 'ILIMITADO'
    },
    {
      'id': 'local-p3',
      'name': 'Élite',
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
      'name': 'Cuerpo completo principiante',
      'level': 'Principiante',
      'duration': 45,
      'exercises': 8,
      'assigned': 0,
      'equipment': 'Sin equipamiento'
    },
    {
      'id': 'r2',
      'name': 'Hipertrofia avanzada',
      'level': 'Avanzado',
      'duration': 60,
      'exercises': 12,
      'assigned': 0,
      'equipment': 'Con pesas'
    },
    {
      'id': 'r3',
      'name': 'Empuje, tirón y piernas',
      'level': 'Intermedio',
      'duration': 55,
      'exercises': 9,
      'assigned': 0,
      'equipment': 'Con pesas'
    },
    {
      'id': 'r4',
      'name': 'Circuito de cardio HIIT',
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
      'muscle': 'Zona media',
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
      'muscle': 'Zona media',
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
      'specialty': 'Fuerza y potencia',
      'clients': 18,
      'rating': 5.0,
      'schedule': '06:00 - 14:00',
      'phone': '+1 555 0101'
    },
    {
      'id': 't2',
      'name': 'Maria Lopez',
      'specialty': 'Yoga y Pilates',
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
      'specialty': 'Ciclismo en sala',
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
      'name': 'Yoga en movimiento',
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
      'name': 'Ciclismo en sala',
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
      'name': 'CrossFit: entrenamiento del día',
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
      'name': 'CrossFit: entrenamiento del día',
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
      'name': 'Ciclismo en sala',
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
      'name': 'Yoga en movimiento',
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
      'name': 'Ciclismo en sala',
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
      'name': 'Yoga en movimiento',
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
      'name': 'CrossFit: entrenamiento del día',
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
      'name': 'Ciclismo en sala',
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
      'name': 'Yoga en movimiento',
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
      'name': 'Ciclismo en sala',
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
      'name': 'CrossFit: entrenamiento del día',
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
    if (newSection == 8) {
      _loadAccessHistory();
      _stopQrRefreshTimer();
      _stopSummaryTimer();
    } else if (newSection == 2) {
      _startQrRefreshTimer();
      _startSummaryTimer();
    } else if (newSection == 0) {
      _stopQrRefreshTimer();
      _startSummaryTimer();
      loadCheckins(); // ✅ Refresca aforo al volver al dashboard
    } else {
      _stopQrRefreshTimer();
      _stopSummaryTimer();
    }
  }

  void _goBackInApp() {
    if (_sectionHistory.isNotEmpty) {
      final prev = _sectionHistory.removeLast();
      setState(() => _section = prev);
      if (prev == 2) {
        _startQrRefreshTimer();
        _startSummaryTimer();
      } else if (prev == 0) {
        _stopQrRefreshTimer();
        _startSummaryTimer();
        loadCheckins(); // ✅ Refresca aforo
      } else {
        _stopQrRefreshTimer();
        _stopSummaryTimer();
      }
    } else if (_section != 0) {
      setState(() => _section = 0);
      _stopQrRefreshTimer();
      _startSummaryTimer();
      loadCheckins();
    }
  }

  void _startQrRefreshTimer() {
    _qrRefreshTimer?.cancel();
    _qrRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _section == 2) setState(() {});
    });
  }

  void _stopQrRefreshTimer() {
    _qrRefreshTimer?.cancel();
    _qrRefreshTimer = null;
  }

  void _startSummaryTimer() {
    _summaryTimer?.cancel();
    _summaryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && (_section == 2 || _section == 0)) {
        loadTodaySummary();
        if (_section == 0) loadCheckins();
      }
    });
  }

  void _stopSummaryTimer() {
    _summaryTimer?.cancel();
    _summaryTimer = null;
  }

  String _sectionTitle() {
    const titles = [
      'Centro de operaciones',
      'Clientes',
      'Acceso QR',
      'Membresías',
      'Finanzas',
      'Entrenamiento',
      'Alertas',
      'Configuración',
      'Historial de accesos',
    ];
    if (_section >= 0 && _section < titles.length) return titles[_section];
    return 'Centro de operaciones';
  }

  bool _canLeaveApp() => _section == 0 && _sectionHistory.isEmpty;

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
    if (alertFilter == 'PENDIENTES') {
      return all.where((a) => a['type'] == 'PENDIENTE').toList();
    }
    if (alertFilter == 'VENCIDAS') {
      return all.where((a) => a['type'] == 'VENCIDA').toList();
    }
    if (alertFilter == 'POR VENCER') {
      return all.where((a) => a['type'] == 'POR VENCER').toList();
    }
    if (alertFilter == 'INFO') {
      return all.where((a) => a['type'] == 'AFORO').toList();
    }
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
      await _syncQrFromCloud();
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
      await addActivity('NUEVO REGISTRO', name);
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
    _stopQrRefreshTimer();
    _stopSummaryTimer();
    _alertTimer?.cancel();
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
      insidePeople.clear();
      lastAccessAlert = null;
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

    await addActivity('RENOVACIÓN', '$name solicitó renovación');
    await _saveLocalData();

    try {
      await Supabase.instance.client.from('renewal_requests').insert({
        'member_id': client['id'].toString(),
        'name': name,
        'cedula': cedula,
        'plan': plan,
        'expiry': expiry,
      });
    } catch (e) {
      debugPrint('⚠️ Renovación guardada solo local: $e');
    }

    if (!mounted) return;
    final ctx = context;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: const Text(
            '✅ Solicitud enviada. El gimnasio recibió tu notificación.'),
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
      final startOfLocalDay = DateTime(now.year, now.month, now.day);
      final startOfDayUtc = startOfLocalDay.toUtc().toIso8601String();

      final response = await supabase
          .from('checkins')
          .select('member_id, type, authorized, created_at')
          .gte('created_at', startOfDayUtc)
          .order('created_at', ascending: true);

      final Map<String, bool> insideState = {};
      for (final row in response) {
        final mid = row['member_id']?.toString();
        if (mid == null) continue;
        final type = (row['type'] ?? '').toString().toUpperCase();
        final authorized = row['authorized'] ?? true;
        if (type == 'ENTRADA' && authorized == true) {
          insideState[mid] = true;
        } else if (type == 'SALIDA') {
          insideState.remove(mid);
        }
      }
      final finalInside = insideState.length;

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
      final sixtyDaysAgoUtc = sixtyDaysAgo.toUtc().toIso8601String();

      final response = await supabase
          .from('checkins')
          .select('created_at')
          .eq('member_id', memberId)
          .eq('type', 'ENTRADA')
          .gte('created_at', sixtyDaysAgoUtc)
          .order('created_at', ascending: false);

      final Set<String> uniqueDays = {};
      for (final row in response) {
        final d = DateTime.tryParse(row['created_at'].toString())?.toLocal() ??
            DateTime.now();
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

  Future<void> _saveLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('members', jsonEncode(members));
      await prefs.setString('plans', jsonEncode(plans));

      final safeTransactions = transactions.map((t) {
        final copy = Map<String, dynamic>.from(t);
        if (copy['created_at'] is DateTime) {
          copy['created_at'] =
              (copy['created_at'] as DateTime).toIso8601String();
        }
        return copy;
      }).toList();
      await prefs.setString('transactions', jsonEncode(safeTransactions));

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
      await prefs.setString('qrToken', qrToken);
      await prefs.setString('qrGenerated', qrGenerated.toIso8601String());
      await prefs.setString('qrExpires', qrExpires.toIso8601String());
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

      final savedQrToken = prefs.getString('qrToken');
      final savedQrExpires = prefs.getString('qrExpires');
      final savedQrGenerated = prefs.getString('qrGenerated');
      if (savedQrToken != null && savedQrToken.isNotEmpty) {
        final exp = DateTime.tryParse(savedQrExpires ?? '');
        if (exp != null && exp.isAfter(DateTime.now())) {
          qrToken = savedQrToken;
          qrExpires = exp;
          qrGenerated =
              DateTime.tryParse(savedQrGenerated ?? '') ?? DateTime.now();
        }
      }

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

      if (mounted) {
        _capacityController.text = capacity.toString();
      }
    } catch (e) {
      debugPrint('❌ Error cargando local: $e');
    }
  }

  // ✅ NUEVO WIDGET BASE PARA EL EFECTO CRISTAL (GLASSMORPHISM)
  Widget _buildGlassCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
    Color? glowColor,
    VoidCallback? onTap,
    EdgeInsetsGeometry? margin,
  }) {
    Widget content = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: context.colors.bg.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          if (glowColor != null)
            BoxShadow(
              color: glowColor.withValues(alpha: 0.15),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: content,
        ),
      );
    }
    return content;
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
          final localExpenses =
              transactions.where((t) => t['type'] == 'EGRESO').toList();
          transactions = [...loaded, ...localExpenses]..sort((a, b) =>
              (_transactionDate(b) ?? DateTime(0))
                  .compareTo(_transactionDate(a) ?? DateTime(0)));
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
          .limit(50);
      if (response.isNotEmpty) {
        final loaded = <Map<String, String>>[];
        for (final row in response) {
          final createdAt =
              DateTime.tryParse(row['created_at'].toString()) ?? DateTime.now();
          loaded.add({
            'type': row['type'] ?? '',
            'name': row['name'] ?? '',
            'time': _fmtTime(createdAt),
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
      final startOfLocalDay = DateTime(now.year, now.month, now.day);
      final startOfDayUtc = startOfLocalDay.toUtc().toIso8601String();

      final response = await supabase
          .from('checkins')
          .select('member_id, type, authorized, created_at')
          .gte('created_at', startOfDayUtc)
          .order('created_at', ascending: true);

      final Map<String, bool> insideState = {};
      for (final row in response) {
        final mid = row['member_id']?.toString();
        if (mid == null) continue;
        final type = (row['type'] ?? '').toString().toUpperCase();
        final authorized = row['authorized'] ?? true;
        if (type == 'ENTRADA' && authorized == true) {
          insideState[mid] = true;
        } else if (type == 'SALIDA') {
          insideState.remove(mid);
        }
      }
      final finalInside = insideState.length;

      if (!mounted) return;
      setState(() {
        inside = finalInside;
        loadingCheckins = false;
      });
      await loadInsidePeople();
      await loadTodaySummary();
    } catch (e) {
      debugPrint('❌ Error cargando checkins: $e');
      if (mounted) setState(() => loadingCheckins = false);
    }
  }

  Future<void> loadInsidePeople() async {
    try {
      final supabase = Supabase.instance.client;

      final now = DateTime.now();
      final startOfLocalDay = DateTime(now.year, now.month, now.day);
      final startOfDayUtc = startOfLocalDay.toUtc().toIso8601String();

      final checkins = await supabase
          .from('checkins')
          .select(
              'member_id, type, authorized, created_at, members(name, plan, phone)')
          .gte('created_at', startOfDayUtc)
          .order('created_at', ascending: true);

      final Map<String, Map<String, dynamic>> state = {};
      for (final row in checkins) {
        final mid = row['member_id']?.toString();
        if (mid == null) continue;
        final type = (row['type'] ?? '').toString().toUpperCase();
        final authorized = row['authorized'] ?? true;
        final memberData = row['members'];
        final name = memberData != null
            ? (memberData['name'] ?? 'Sin nombre')
            : 'Sin nombre';
        final plan = memberData != null ? (memberData['plan'] ?? '—') : '—';
        final phone = memberData != null ? (memberData['phone'] ?? '') : '';
        final createdAt =
            DateTime.tryParse(row['created_at'].toString())?.toLocal() ?? now;

        if (type == 'ENTRADA' && authorized == true) {
          state[mid] = {
            'id': mid,
            'name': name,
            'plan': plan,
            'phone': phone,
            'entryTime': createdAt,
          };
        } else if (type == 'SALIDA') {
          state.remove(mid);
        }
      }
      if (!mounted) return;
      setState(() {
        insidePeople = state.values.toList()
          ..sort((a, b) => (b['entryTime'] as DateTime)
              .compareTo(a['entryTime'] as DateTime));
      });
    } catch (e) {
      debugPrint('❌ Error cargando aforo detallado: $e');
    }
  }

  Future<void> loadAllData() async {
    await _loadLocalData();
    if (mounted) setState(() => loadingData = false);
    _syncWithSupabase();
  }

  Future<void> loadRenewalRequests() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('renewal_requests')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          renewalRequests = response
              .map((r) => {
                    'id': r['id'].toString(),
                    'memberId': r['member_id'].toString(),
                    'name': r['name'] ?? '',
                    'cedula': r['cedula'] ?? '',
                    'plan': r['plan'] ?? '',
                    'expiry': r['expiry'] ?? '',
                    'createdAt': r['created_at'],
                    'read': r['read'] ?? false,
                  })
              .toList();
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error cargando renovaciones: $e');
    }
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
      await loadRenewalRequests();
    } catch (_) {}
    try {
      await loadCheckins();
    } catch (_) {}

    try {
      final settings = await Supabase.instance.client
          .from('gym_settings')
          .select()
          .eq('key', 'capacity')
          .maybeSingle();
      if (settings != null) {
        final v = int.tryParse(settings['value']?.toString() ?? '');
        if (v != null && v > 0 && mounted) {
          setState(() {
            capacity = v;
            _capacityController.text = v.toString();
          });
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('capacity', v);
          debugPrint('✅ Capacity cargada de Supabase: $v');
        }
      }
    } catch (e) {
      debugPrint('⚠️ No se pudo leer capacity de Supabase: $e');
    }

    try {
      await _syncQrFromCloud();
    } catch (e) {
      debugPrint('⚠️ No se pudo leer QR de Supabase: $e');
    }

    await _saveLocalData();
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inHours < 24 && now.day == d.day) {
      return 'Hoy ${_fmtTime(d)}';
    }
    if (diff.inDays < 2) {
      return 'Ayer ${_fmtTime(d)}';
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

  Future<void> addActivity(String type, String name) async {
    if (!mounted) return;
    final now = DateTime.now();
    setState(() {
      activities.insert(0, {
        'type': type,
        'name': name,
        'time': _fmtTime(now),
      });
      if (activities.length > 50) activities.removeLast();
    });
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('activities').insert({
        'type': type,
        'name': name,
      });
    } catch (e) {
      debugPrint('⚠️ Actividad solo local: $e');
    }
    await _saveLocalData();
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
    _saveLocalData();
    _scheduleDailyQrRefresh();
    _syncQrToCloud();
  }

  Future<void> _scheduleDailyQrRefresh() async {
    if (qrMode != 'DIARIO') return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('qrMode', qrMode);
    if (!mounted) return;

    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 1);
    final diff = nextMidnight.difference(now);

    Future.delayed(diff, () {
      if (!mounted) return;
      if (qrMode == 'DIARIO') {
        generateGymQr();
      }
    });
  }

  Future<void> _syncQrToCloud() async {
    try {
      await Supabase.instance.client.from('gym_settings').upsert([
        {'key': 'qr_token', 'value': qrToken},
        {'key': 'qr_expires', 'value': qrExpires.toUtc().toIso8601String()},
        {'key': 'qr_mode', 'value': qrMode},
      ], onConflict: 'key');
      debugPrint('✅ QR sincronizado a Supabase');
    } catch (e) {
      debugPrint('⚠️ No se pudo sincronizar QR a Supabase: $e');
    }
  }

  Future<void> _syncQrFromCloud() async {
    try {
      final qrRows = await Supabase.instance.client
          .from('gym_settings')
          .select()
          .inFilter('key', ['qr_token', 'qr_expires', 'qr_mode']);
      if (qrRows.isNotEmpty) {
        final map = {for (final r in qrRows) r['key']: r['value']};
        final token = map['qr_token']?.toString();
        final expiresStr = map['qr_expires']?.toString();
        final mode = map['qr_mode']?.toString();
        if (token != null && token.isNotEmpty) {
          if (mounted) {
            setState(() {
              qrToken = token;
              if (mode != null) qrMode = mode;
              final exp = DateTime.tryParse(expiresStr ?? '');
              if (exp != null) qrExpires = exp.toLocal();
            });
          }
          await _saveLocalData();
        }
      }
    } catch (e) {
      debugPrint('⚠️ No se pudo leer QR de Supabase: $e');
    }
  }

  String get qrTimeLeft {
    final now = DateTime.now();
    final diff = qrExpires.difference(now);
    if (diff.isNegative) return 'EXPIRADO';
    if (diff.inDays > 0) {
      final unit = diff.inDays == 1 ? 'día' : 'días';
      return 'Expira en ${diff.inDays} $unit';
    }
    if (diff.inHours > 0) {
      final unit = diff.inHours == 1 ? 'hora' : 'horas';
      return 'Expira en ${diff.inHours} $unit';
    }
    final minutes = diff.inMinutes;
    final unit = minutes == 1 ? 'minuto' : 'minutos';
    return 'Expira en $minutes $unit';
  }

  void _triggerDashboardAlert(String memberName, String status,
      {String type = 'ENTRADA'}) {
    Color alertColor;
    String alertTitle;
    IconData alertIcon;

    if (type == 'SALIDA') {
      alertColor = const Color(0xFF9C27B0); // ✅ MORADO PARA SALIDAS
      alertTitle = 'SALIDA REGISTRADA';
      alertIcon = Icons.logout_rounded;
    } else if (status == 'ACTIVO') {
      alertColor = context.colors.green;
      alertTitle = 'ENTRADA PERMITIDA';
      alertIcon = Icons.check_circle_rounded;
    } else if (status == 'POR VENCER') {
      alertColor = context.colors.yellow;
      alertTitle = 'ENTRADA CON MEMBRESÍA POR VENCER';
      alertIcon = Icons.warning_amber_rounded;
    } else {
      alertColor = context.colors.red;
      alertTitle = 'ACCESO DENEGADO';
      alertIcon = Icons.block_rounded;
    }

    setState(() {
      lastAccessAlert = {
        'name': memberName,
        'status': status,
        'color': alertColor,
        'title': alertTitle,
        'icon': alertIcon,
      };
    });

    _alertTimer?.cancel();
    _alertTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => lastAccessAlert = null);
    });
  }

  Future<void> _processGymQrScan(String scannedCode) async {
    if (_qrProcessing) return;
    if (loggedClient == null) return;
    _qrProcessing = true;
    final client = loggedClient!;
    final memberId = client['id'];
    final memberName = client['name'].toString();
    final status = client['status'].toString().toUpperCase();

    try {
      if (!scannedCode.startsWith('SYNTH-GYM-')) {
        await _showAccessOverlay(
          success: false,
          title: 'QR INVÁLIDO',
          subtitle: 'Este código no pertenece al gimnasio.',
          name: memberName,
          status: 'INVÁLIDO',
        );
        return;
      }

      if (qrMode != 'FIJO' && DateTime.now().isAfter(qrExpires)) {
        await _showAccessOverlay(
          success: false,
          title: 'QR EXPIRADO',
          subtitle: 'El código del gimnasio ha vencido. Pide uno nuevo.',
          name: memberName,
          status: 'EXPIRADO',
        );
        return;
      }

      if (qrToken.isNotEmpty && scannedCode != qrToken) {
        await _showAccessOverlay(
          success: false,
          title: 'QR NO VIGENTE',
          subtitle: 'Este código ya no es válido. Escanea el QR actual.',
          name: memberName,
          status: 'OBSOLETO',
        );
        return;
      }

      final supabase = Supabase.instance.client;
      final now = DateTime.now();
      final startOfLocalDay = DateTime(now.year, now.month, now.day);
      final startOfDayUtc = startOfLocalDay.toUtc().toIso8601String();

      final todayCheckins = await supabase
          .from('checkins')
          .select('type')
          .eq('member_id', memberId)
          .gte('created_at', startOfDayUtc)
          .order('created_at', ascending: true);

      final lastType = todayCheckins.isNotEmpty
          ? todayCheckins.last['type'].toString().toUpperCase()
          : '';

      if (lastType == 'ENTRADA') {
        await _showAccessOverlay(
          success: false,
          title: 'YA ESTÁS DENTRO',
          subtitle: 'Ya registraste tu entrada hoy. Disfruta tu entrenamiento.',
          name: memberName,
          status: 'DENTRO',
        );
        return;
      } else if (lastType == 'SALIDA') {
        await _showAccessOverlay(
          success: false,
          title: 'YA SALISTE HOY',
          subtitle: 'Ya registraste tu salida por hoy. Nos vemos mañana.',
          name: memberName,
          status: 'SALIDA',
        );
        return;
      }

      String type = 'ENTRADA';
      final isBlocked = status != 'ACTIVO';

      await supabase.from('checkins').insert({
        'member_id': memberId,
        'type': type,
        'authorized': !isBlocked,
        'reason': isBlocked ? 'Membresía $status' : null,
        'registered_by': 'client_qr',
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
          });
          await loadClientStreak();
        }
      }

      if (mounted) addActivity(isBlocked ? 'BLOQUEADO' : type, memberName);

      await loadActivities();
      await loadCheckins();
      await loadClientAforo();
      await _saveLocalData();

      if (!mounted) return;
      if (mounted) setState(() {});

      _triggerDashboardAlert(memberName, status, type: type);

      if (type == 'ENTRADA') {
        await _showAccessOverlay(
          success: !isBlocked,
          title: isBlocked ? 'ACCESO DENEGADO' : 'BIENVENIDO',
          subtitle: isBlocked
              ? 'Membresía $status. Contacta al gimnasio.'
              : '¡Que tengas un excelente entrenamiento!',
          name: memberName,
          status: status,
          type: type,
        );
      }
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
                          fontSize: 28,
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
                                fontSize: 22,
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
                              _fmtTime(DateTime.now()),
                              style: TextStyle(
                                color: dialogContext.colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                            if (type != null && type == 'ENTRADA') ...[
                              const SizedBox(height: 8),
                              Text(
                                '↑ ENTRADA REGISTRADA',
                                style: TextStyle(
                                  color: dialogContext.colors.muted,
                                  fontSize: 12,
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
          title: Row(children: [
            Icon(Icons.warning_amber_rounded,
                color: dialogContext.colors.red, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text('RESET AFORO',
                  style: TextStyle(
                    color: dialogContext.colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  )),
            ),
          ]),
          content: Text(
            'Esto SOLO reiniciará el aforo del día de hoy (entradas y salidas). Úsalo si se descuadró porque alguien no registró su salida.\n\nEl historial de actividades y los clientes NO se borrarán.',
            style: TextStyle(
              color: dialogContext.colors.muted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('CANCELAR',
                  style: TextStyle(color: dialogContext.colors.muted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: dialogContext.colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('REINICIAR AFORO',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;

    setState(() => loadingCheckins = true);

    try {
      final supabase = Supabase.instance.client;

      final now = DateTime.now();
      final startOfLocalDay = DateTime(now.year, now.month, now.day);
      final endOfLocalDay = startOfLocalDay.add(const Duration(days: 1));

      final startOfDayUtc = startOfLocalDay.toUtc().toIso8601String();
      final endOfDayUtc = endOfLocalDay.toUtc().toIso8601String();

      debugPrint(
          '🗑️ Borrando aforo desde: $startOfDayUtc hasta: $endOfDayUtc');

      await supabase
          .from('checkins')
          .delete()
          .gte('created_at', startOfDayUtc)
          .lt('created_at', endOfDayUtc);

      debugPrint('✅ Aforo borrado en Supabase completado');

      setState(() {
        inside = 0;
        clientInsideCount = 0;
        insidePeople.clear();
        todayEntries = 0;
        todayExits = 0;
        todayBlocked = 0;
        todayEntriesList.clear();
        todayExitsList.clear();
        todayBlockedList.clear();
      });

      await _saveLocalData();

      await loadCheckins();
      await loadInsidePeople();
      await loadTodaySummary();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              const Text('✅ Aforo reiniciado. Historial y clientes intactos.'),
          backgroundColor: context.colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error al resetear aforo: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al borrar: $e'),
          backgroundColor: context.colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() => loadingCheckins = false);
    }
  }

  Future<void> showResetDayDialog() => resetAforo();

  Future<void> loadTodaySummary({DateTime? forDate}) async {
    try {
      final supabase = Supabase.instance.client;
      final targetDate = forDate ?? DateTime.now();

      final startOfLocalDay =
          DateTime(targetDate.year, targetDate.month, targetDate.day);
      final endOfLocalDay = startOfLocalDay.add(const Duration(days: 1));

      final startOfDayUtc = startOfLocalDay.toUtc().toIso8601String();
      final endOfDayUtc = endOfLocalDay.toUtc().toIso8601String();

      final response = await supabase
          .from('checkins')
          .select(
              'member_id, type, authorized, reason, created_at, members(name, plan, phone)')
          .gte('created_at', startOfDayUtc)
          .lt('created_at', endOfDayUtc)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> entries = [];
      final List<Map<String, dynamic>> exits = [];
      final List<Map<String, dynamic>> blocked = [];

      for (final row in response) {
        final mid = row['member_id']?.toString();
        if (mid == null) continue;
        final type = (row['type'] ?? '').toString().toUpperCase();
        final authorized = row['authorized'] ?? true;
        final reason = row['reason']?.toString() ?? '';
        final memberData = row['members'];

        final name = memberData != null
            ? (memberData['name'] ?? 'Sin nombre')
            : 'Sin nombre';
        final plan = memberData != null ? (memberData['plan'] ?? '—') : '—';
        final phone = memberData != null ? (memberData['phone'] ?? '') : '';
        final createdAt =
            DateTime.tryParse(row['created_at'].toString())?.toLocal() ??
                DateTime.now();

        final item = {
          'id': mid,
          'name': name,
          'plan': plan,
          'phone': phone,
          'time': _fmtTime(createdAt),
          'timestamp': createdAt,
          'reason': reason,
        };

        if (authorized == false) {
          blocked.add(item);
        } else if (type == 'ENTRADA') {
          entries.add(item);
        } else if (type == 'SALIDA') {
          exits.add(item);
        }
      }

      if (mounted) {
        setState(() {
          summarySelectedDate = targetDate;
          todayEntriesList = entries;
          todayExitsList = exits;
          todayBlockedList = blocked;

          todayEntries = entries.length;
          todayExits = exits.length;
          todayBlocked = blocked.length;

          todayIncome = 0.0;
          for (var tx in transactions) {
            final txDate = tx['created_at'] as DateTime?;
            if (txDate != null &&
                txDate.year == targetDate.year &&
                txDate.month == targetDate.month &&
                txDate.day == targetDate.day &&
                tx['type'] == 'INGRESO') {
              todayIncome += (tx['amount'] as num).toDouble();
            }
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Error cargando resumen del día: $e');
    }
  }

  Future<void> _pickHistoryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: summarySelectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: context.colors.red,
              onPrimary: Colors.white,
              surface: context.colors.panel,
              onSurface: context.colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      await loadTodaySummary(forDate: picked);
    }
  }

  Future<void> _showTodayStatSheet({required String type}) async {
    await loadTodaySummary(forDate: summarySelectedDate);
    if (!mounted) return;

    List<Map<String, dynamic>> dataList;
    String title;
    IconData icon;
    Color color;

    if (type == 'DENTRO') {
      dataList = insidePeople;
      title = 'DENTRO AHORA';
      icon = Icons.people_alt_rounded;
      color = context.colors.green;
    } else if (type == 'ENTRADAS') {
      dataList = todayEntriesList;
      title = 'ENTRADAS';
      icon = Icons.login_rounded;
      color = context.colors.blue;
    } else if (type == 'SALIDAS') {
      dataList = todayExitsList;
      title = 'SALIDAS';
      icon = Icons.logout_rounded;
      color = context.colors.yellow;
    } else {
      dataList = todayBlockedList;
      title = 'BLOQUEADOS';
      icon = Icons.block_rounded;
      color = context.colors.red;
    }

    final isToday = summarySelectedDate.year == DateTime.now().year &&
        summarySelectedDate.month == DateTime.now().month &&
        summarySelectedDate.day == DateTime.now().day;

    final dateLabel = isToday
        ? 'HOY · ${summarySelectedDate.day} ${_monthName(summarySelectedDate.month)}'
        : '${summarySelectedDate.day} ${_monthName(summarySelectedDate.month)} ${summarySelectedDate.year}';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
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
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(icon, color: color, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  style: TextStyle(
                                    color: sheetContext.colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  )),
                              const SizedBox(height: 2),
                              Text(
                                  '$dateLabel · ${dataList.length} registro(s)',
                                  style: TextStyle(
                                    color: sheetContext.colors.muted,
                                    fontSize: 11,
                                  )),
                            ],
                          ),
                        ),
                        if (type != 'DENTRO')
                          IconButton(
                            tooltip: 'Ver historial',
                            onPressed: () async {
                              await _pickHistoryDate();
                              setModalState(() {
                                if (type == 'ENTRADAS')
                                  dataList = todayEntriesList;
                                if (type == 'SALIDAS')
                                  dataList = todayExitsList;
                                if (type == 'BLOQUEADOS')
                                  dataList = todayBlockedList;
                              });
                            },
                            icon: Icon(Icons.calendar_month_rounded,
                                color: sheetContext.colors.white, size: 20),
                          ),
                        IconButton(
                          onPressed: () async {
                            await loadTodaySummary(
                                forDate: summarySelectedDate);
                            if (type == 'DENTRO') await loadInsidePeople();
                            setModalState(() {
                              if (type == 'DENTRO') dataList = insidePeople;
                              if (type == 'ENTRADAS')
                                dataList = todayEntriesList;
                              if (type == 'SALIDAS') dataList = todayExitsList;
                              if (type == 'BLOQUEADOS')
                                dataList = todayBlockedList;
                            });
                          },
                          icon: Icon(Icons.refresh_rounded,
                              color: color, size: 20),
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
                      child: dataList.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(40),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.inbox_rounded,
                                        color: sheetContext.colors.muted,
                                        size: 48),
                                    const SizedBox(height: 12),
                                    Text('Sin registros',
                                        style: TextStyle(
                                          color: sheetContext.colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        )),
                                    const SizedBox(height: 4),
                                    Text('No hay movimientos de este tipo',
                                        style: TextStyle(
                                          color: sheetContext.colors.muted,
                                          fontSize: 11,
                                        )),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                              itemCount: dataList.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final p = dataList[i];
                                final name = p['name'].toString();
                                final initial =
                                    name.isEmpty ? '?' : name[0].toUpperCase();
                                final timeStr = p['time']?.toString() ?? '';
                                final plan = p['plan']?.toString() ?? '—';
                                final reason = p['reason']?.toString() ?? '';

                                String extraInfo = plan;
                                if (type == 'DENTRO' &&
                                    p['entryTime'] != null) {
                                  final entry = p['entryTime'] as DateTime;
                                  final mins = DateTime.now()
                                      .difference(entry)
                                      .inMinutes;
                                  extraInfo = '$plan · Lleva $mins min';
                                } else if (reason.isNotEmpty) {
                                  extraInfo = 'Motivo: $reason';
                                }

                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: sheetContext.colors.panel,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: sheetContext.colors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: .15),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(initial,
                                            style: TextStyle(
                                              color: color,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 16,
                                            )),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(name,
                                                style: TextStyle(
                                                  color:
                                                      sheetContext.colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                            const SizedBox(height: 2),
                                            Text(extraInfo,
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
                                      if (timeStr.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: sheetContext.colors.panel2,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                                color:
                                                    sheetContext.colors.border),
                                          ),
                                          child: Text(timeStr,
                                              style: TextStyle(
                                                color:
                                                    sheetContext.colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w900,
                                              )),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ⚡ AQUÍ EMPIEZA EL NUEVO DISEÑO VISUAL (BENTO GRID Y HEADER)
  // ═══════════════════════════════════════════════════════════════════

  Widget _dashboardContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;
        final espacio = isMobile ? 16.0 : 24.0;
        final dashboardWidth = constraints.maxWidth - espacio * 2;

        if (isMobile) {
          return AdminHomeMobile(
            inside: inside,
            capacity: capacity,
            income: totalIncome,
            activeMembers: members.where((m) => m['status'] == 'ACTIVO').length,
            expiringSoon:
                members.where((m) => m['status'] == 'POR VENCER').length,
            expired: members.where((m) => m['status'] == 'VENCIDO').length,
            activities: activities,
            notificationCount: alertCount(context),
            adminName: 'SYNTHETIX',
            onScan: showAccessScanner,
            onNewPayment: newPayment,
            onNewMember: addMember,
            onOpenNotifications: showNotifications,
            onOpenMore: () => _goToSection(8),
            onOpenMemberships: () => _goToSection(3),
            onOpenClients: () => _goToSection(1),
            onOpenFinance: () => _goToSection(4),
          );
        }

        // BENTO GRID WEB PRO
        return SingleChildScrollView(
          padding: EdgeInsets.all(espacio),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Limpio + Buscador (Estilo Cristal)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hola, administrador',
                          style: TextStyle(
                              color: context.colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5)),
                      const SizedBox(height: 4),
                      Text('Consulta y administra la operación de tu gimnasio.',
                          style: TextStyle(
                              color: context.colors.muted, fontSize: 14)),
                    ],
                  ),
                  if (constraints.maxWidth >= 1200)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: context.colors.panel.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: context.colors.border
                                    .withValues(alpha: 0.7)),
                          ),
                          child: TextField(
                            style: TextStyle(color: context.colors.white),
                            onSubmitted: (value) {
                              searchController.text = value.trim();
                              clientFilter = 'TODOS';
                              _goToSection(1);
                            },
                            decoration: InputDecoration(
                              hintText: 'Buscar clientes, planes o pagos...',
                              hintStyle: TextStyle(color: context.colors.muted),
                              prefixIcon: Icon(Icons.search_rounded,
                                  color: context.colors.muted),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 15),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 12),
                  Row(
                    children: [
                      Stack(
                        children: [
                          IconButton(
                              tooltip: 'Ver alertas',
                              onPressed: showNotifications,
                              icon: Icon(Icons.notifications_none_rounded,
                                  color: context.colors.white)),
                          if (alertCount(context) > 0)
                            Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                        color: context.colors.red,
                                        shape: BoxShape.circle))),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: context.colors.border, width: 2),
                          boxShadow: [
                            BoxShadow(
                                color: context.colors.green
                                    .withValues(alpha: 0.16),
                                blurRadius: 12)
                          ],
                        ),
                        child: Center(
                            child: Text('A',
                                style: TextStyle(
                                    color: context.colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 20))),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // 2. Indicadores principales
              Builder(
                builder: (context) {
                  final columns = dashboardWidth >= 1250
                      ? 4
                      : dashboardWidth >= 700
                          ? 2
                          : 1;
                  final cardWidth =
                      (dashboardWidth - (columns - 1) * 16) / columns;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _bentoCard(
                          'Ingresos acumulados',
                          formatPrice(totalIncome),
                          'Histórico',
                          Icons.payments_rounded,
                          context.colors.green,
                          chart: _MiniChartPainter(
                              data: monthlyIncome, color: context.colors.green),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _bentoCard(
                          'Miembros activos',
                          activeMembers.toString(),
                          'Membresías al día',
                          Icons.people_alt_rounded,
                          context.colors.green,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _bentoCard(
                          'Por vencer',
                          members
                              .where((m) => m['status'] == 'POR VENCER')
                              .length
                              .toString(),
                          'Revisar renovaciones',
                          Icons.event_busy_rounded,
                          const Color(0xFFFFD54F),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _bentoCard(
                          'Aforo actual',
                          '$inside/$capacity',
                          '${(occupancy * 100).round()}% de capacidad',
                          Icons.groups_rounded,
                          context.colors.green,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // 3. Gráfico Principal Animado y Tarjetas Secundarias
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: dashboardWidth >= 1100
                        ? (dashboardWidth - 16) * .6
                        : dashboardWidth,
                    child: _buildGlassCard(
                      glowColor: context.colors.green,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Ingresos mensuales del gimnasio',
                                  style: TextStyle(
                                      color: context.colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900)),
                              Icon(Icons.more_horiz_rounded,
                                  color: context.colors.muted),
                            ],
                          ),
                          Text('Evolución de ingresos por mes',
                              style: TextStyle(
                                  color: context.colors.muted, fontSize: 12)),
                          const SizedBox(height: 30),
                          SizedBox(
                            height: 220,
                            child: Stack(
                              children: [
                                AnimatedBentoChart(
                                    color: context.colors.green,
                                    data: monthlyIncome),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: dashboardWidth >= 1100
                        ? (dashboardWidth - 16) * .4
                        : dashboardWidth,
                    child: Column(
                      children: [
                        _buildGlassCard(
                          glowColor: context.colors.green,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Actividad del gimnasio',
                                  style: TextStyle(
                                      color: context.colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900)),
                              const SizedBox(height: 16),
                              _rowInfo('Entradas de hoy', 'Accesos',
                                  '$todayEntries'),
                              _rowInfo(
                                  'Salidas de hoy', 'Accesos', '$todayExits'),
                              _rowInfo('Accesos bloqueados', 'Control',
                                  '$todayBlocked'),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Aforo actual',
                                      style: TextStyle(
                                          color: context.colors.muted,
                                          fontSize: 12)),
                                  Text('$inside / $capacity',
                                      style: TextStyle(
                                          color: context.colors.white,
                                          fontWeight: FontWeight.bold)),
                                ],
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildGlassCard(
                          glowColor: context.colors.border,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Actividad reciente',
                                  style: TextStyle(
                                      color: context.colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900)),
                              const SizedBox(height: 12),
                              if (activities.isEmpty)
                                Text('Sin actividad reciente',
                                    style: TextStyle(
                                        color: context.colors.muted,
                                        fontSize: 12))
                              else
                                ...activities.take(3).map((a) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          Icon(Icons.check_circle,
                                              color: context.colors.green,
                                              size: 14),
                                          const SizedBox(width: 8),
                                          Expanded(
                                              child: Text(a['name'].toString(),
                                                  style: TextStyle(
                                                      color:
                                                          context.colors.white,
                                                      fontSize: 12),
                                                  overflow:
                                                      TextOverflow.ellipsis)),
                                        ],
                                      ),
                                    )),
                            ],
                          ),
                        )
                      ],
                    ),
                  )
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _bentoCard(
    String title,
    String value,
    String detail,
    IconData icon,
    Color color, {
    CustomPainter? chart,
  }) {
    return _buildGlassCard(
      glowColor: color,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 19)),
              if (detail.isNotEmpty)
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(detail,
                        style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 20),
          Text(title,
              style: TextStyle(
                  color: context.colors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: context.colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5)),
          const SizedBox(height: 12),
          if (chart != null)
            SizedBox(
              height: 30,
              child:
                  CustomPaint(painter: chart, child: const SizedBox.expand()),
            ),
        ],
      ),
    );
  }

  Widget _rowInfo(String t1, String t2, String amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
              flex: 2,
              child: Text(t1,
                  style: TextStyle(color: context.colors.white, fontSize: 12))),
          Expanded(
              flex: 2,
              child: Text(t2,
                  style: TextStyle(color: context.colors.muted, fontSize: 12))),
          Text(amount,
              style: TextStyle(
                  color: context.colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _header() {
    final ac = alertCount(context) + renewalRequests.length;
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border(
              bottom: BorderSide(
                  color: context.colors.white.withValues(alpha: 0.05)))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_sectionTitle().toUpperCase(),
                    style: TextStyle(
                        color: context.colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5)),
                const SizedBox(height: 2),
                Text('SYNTHETIX GYM OS PRO',
                    style: TextStyle(
                        color: context.colors.muted,
                        fontSize: 11,
                        letterSpacing: 1)),
              ],
            ),
          ),
          IconButton(
              onPressed: () => loadAllData(),
              icon: Icon(Icons.refresh_rounded, color: context.colors.muted)),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => themeController.toggle(),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: context.colors.panel.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: context.colors.white.withValues(alpha: 0.05))),
                child: Icon(
                    themeController.isDark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    color: context.colors.white,
                    size: 18),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Stack(
            children: [
              IconButton(
                  onPressed: showNotifications,
                  icon: Icon(Icons.notifications_none_rounded,
                      color: context.colors.white)),
              if (ac > 0)
                Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                        padding: const EdgeInsets.all(4),
                        constraints:
                            const BoxConstraints(minWidth: 16, minHeight: 16),
                        decoration: BoxDecoration(
                            color: context.colors.red, shape: BoxShape.circle),
                        child: Text('$ac',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900)))),
            ],
          ),
          const SizedBox(width: 16),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFD54F), width: 2),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFFFFD54F).withValues(alpha: 0.3),
                      blurRadius: 10)
                ]),
            child: Center(
                child: Text('A',
                    style: TextStyle(
                        color: context.colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16))),
          ),
        ],
      ),
    );
  }

  Widget _hero() => const SizedBox.shrink();

  Widget _modalHeader(BuildContext ctx, String title) {
    return Row(children: [
      Expanded(
          child: Text(title,
              style: TextStyle(
                  color: ctx.colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900))),
      IconButton(
          onPressed: () => Navigator.pop(ctx),
          icon: Icon(Icons.close_rounded, color: ctx.colors.muted)),
    ]);
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
                    await addActivity('NUEVO MIEMBRO', name.text.trim());
                    navigator.pop();
                    messenger.showSnackBar(SnackBar(
                        content: const Text('Miembro creado correctamente'),
                        backgroundColor: ctx.colors.green));
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
                      await supabase.from('activities').insert(
                          {'type': 'NUEVO MIEMBRO', 'name': name.text.trim()});
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
                    await addActivity('EDITADO', name.text.trim());
                    navigator.pop();
                    messenger.showSnackBar(SnackBar(
                        content:
                            const Text('Miembro actualizado correctamente'),
                        backgroundColor: ctx.colors.green));
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
                        'cedula': cedula.text.trim(),
                        'expiry': expiry.text.trim(),
                        'plan': plan,
                        'status': status,
                      }).eq('id', memberId);
                      await supabase.from('activities').insert(
                          {'type': 'EDITADO', 'name': name.text.trim()});
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
              Text('¿Eliminar a ${member['name']}?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: dialogContext.colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('Esta acción no se puede deshacer.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: dialogContext.colors.muted, fontSize: 13)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              side: BorderSide(
                                  color: dialogContext.colors.border),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13))),
                          child: Text('CANCELAR',
                              style: TextStyle(
                                  color: dialogContext.colors.white,
                                  fontWeight: FontWeight.w900)))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: ElevatedButton(
                          onPressed: () async {
                            final navigator = Navigator.of(dialogContext);
                            final messenger =
                                ScaffoldMessenger.of(dialogContext);
                            final ctx = dialogContext;
                            final memberId = member['id'];
                            setState(() {
                              members.remove(member);
                              activeMembers = members.length;
                            });
                            await addActivity(
                                'ELIMINADO', member['name'].toString());
                            navigator.pop();
                            messenger.showSnackBar(SnackBar(
                                content: Text('${member['name']} eliminado'),
                                backgroundColor: ctx.colors.green));
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
                                'name': member['name'].toString()
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
                                  borderRadius: BorderRadius.circular(13))),
                          child: const Text('ELIMINAR',
                              style: TextStyle(fontWeight: FontWeight.w900)))),
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
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: const Text('No hay miembros registrados'),
          backgroundColor: ctx.colors.red));
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
                        orElse: () => <String, dynamic>{});
                    if (memberData.isEmpty) return;
                    final navigator = Navigator.of(dialogContext);
                    final messenger = ScaffoldMessenger.of(dialogContext);
                    final ctx = dialogContext;
                    final currentPayments =
                        (memberData['payments'] as num?)?.toInt() ?? 0;
                    final currentTotal =
                        (memberData['totalPaid'] as num?)?.toDouble() ?? 0.0;
                    final now = DateTime.now();
                    final memberPlan = memberData['plan'].toString();
                    final newExpiry = _calculateExpiryDate(memberPlan, now);
                    final currentStatus =
                        memberData['status'].toString().toUpperCase();
                    final wasNotActive = currentStatus != 'ACTIVO';
                    setState(() {
                      for (var m in members) {
                        if (m['name'] == memberName) {
                          m['payments'] = currentPayments + 1;
                          m['totalPaid'] = currentTotal + value;
                          m['lastVisit'] = _formatDate(now);
                          if (wasNotActive) {
                            m['status'] = 'ACTIVO';
                            m['expiry'] = newExpiry;
                          }
                          break;
                        }
                      }
                      final newTx = {
                        'name': memberName,
                        'concept': 'Plan $memberPlan',
                        'amount': value,
                        'method': method,
                        'date': _formatDate(now),
                        'type': 'INGRESO',
                        'created_at': now
                      };
                      transactions.insert(0, newTx);
                      income += value;
                    });
                    if (memberData['id'] != null) {
                      dismissedAlerts.remove('vencida-${memberData['id']}');
                      dismissedAlerts.remove('porvencer-${memberData['id']}');
                    }
                    await addActivity('PAGO', memberName);
                    navigator.pop();
                    messenger.showSnackBar(SnackBar(
                        content: Text(wasNotActive
                            ? '✅ Pago registrado · $memberName ahora está ACTIVO hasta $newExpiry'
                            : '✅ Pago registrado correctamente'),
                        backgroundColor: ctx.colors.green,
                        duration: const Duration(seconds: 3)));
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
                        'status': 'Pagado'
                      });
                      final updateData = <String, dynamic>{
                        'payments': currentPayments + 1,
                        'total_paid': currentTotal + value,
                        'last_visit': _formatDate(now)
                      };
                      if (wasNotActive) {
                        updateData['status'] = 'ACTIVO';
                        updateData['expiry'] = newExpiry;
                      }
                      await supabase
                          .from('members')
                          .update(updateData)
                          .eq('id', memberId);
                      await supabase
                          .from('activities')
                          .insert({'type': 'PAGO', 'name': memberName});
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

  void newExpense() {
    final concept = TextEditingController();
    final amount = TextEditingController();
    const categories = [
      'Servicios',
      'Nómina',
      'Mantenimiento',
      'Equipamiento',
      'Otros gastos',
    ];
    String category = categories.first;
    String method = 'EFECTIVO';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return _dialog(
          title: 'REGISTRAR GASTO',
          accent: dialogContext.colors.red,
          child: StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: category,
                    dropdownColor: dialogContext.colors.panel2,
                    style: TextStyle(color: dialogContext.colors.white),
                    decoration:
                        _inputDecoration(dialogContext, 'Categoría del gasto'),
                    items: categories
                        .map((value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => category = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _field(concept, 'Descripción'),
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
                          value: 'EFECTIVO', child: Text('Efectivo')),
                      DropdownMenuItem(
                          value: 'TARJETA', child: Text('Tarjeta')),
                      DropdownMenuItem(
                          value: 'TRANSFERENCIA', child: Text('Transferencia')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => method = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: dialogContext.colors.yellow.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: dialogContext.colors.yellow
                              .withValues(alpha: .3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: dialogContext.colors.yellow, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Los gastos se guardan en este dispositivo y no se sincronizan con la nube.',
                            style: TextStyle(
                              color: dialogContext.colors.muted,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _button('GUARDAR GASTO', dialogContext.colors.red, () async {
                    final value =
                        double.tryParse(amount.text.replaceAll(',', '.'));
                    if (concept.text.trim().isEmpty ||
                        value == null ||
                        value <= 0) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: const Text(
                              'Indica una descripción y un importe válido.'),
                          backgroundColor: dialogContext.colors.red,
                        ),
                      );
                      return;
                    }
                    final now = DateTime.now();
                    setState(() {
                      transactions.insert(0, {
                        'id': 'local-expense-${now.microsecondsSinceEpoch}',
                        'name': category,
                        'concept': concept.text.trim(),
                        'amount': value,
                        'method': method,
                        'date': _formatDate(now),
                        'type': 'EGRESO',
                        'created_at': now,
                        'localOnly': true,
                      });
                    });
                    await _saveLocalData();
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Gasto guardado correctamente.'),
                        backgroundColor: context.colors.green,
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
                      : access.text.trim()
                };
                setState(() => plans.add(localPlan));
                navigator.pop();
                messenger.showSnackBar(SnackBar(
                    content: const Text('Plan creado correctamente'),
                    backgroundColor: ctx.colors.green));
                await _saveLocalData();
                try {
                  final supabase = Supabase.instance.client;
                  await supabase.from('plans').insert({
                    'name': name.text.trim(),
                    'price': p,
                    'days': d,
                    'access': access.text.trim().isEmpty
                        ? 'ILIMITADO'
                        : access.text.trim()
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
                messenger.showSnackBar(SnackBar(
                    content: const Text('Plan actualizado correctamente'),
                    backgroundColor: ctx.colors.green));
                await _saveLocalData();
                final planId = plan['id'];
                if (planId == null || planId.toString().startsWith('local-')) {
                  return;
                }
                try {
                  final supabase = Supabase.instance.client;
                  await supabase.from('plans').update({
                    'name': name.text.trim(),
                    'price': p,
                    'days': d,
                    'access': access.text.trim()
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
              Text('¿Eliminar el plan "${plan['name']}"?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: dialogContext.colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              side: BorderSide(
                                  color: dialogContext.colors.border),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13))),
                          child: Text('CANCELAR',
                              style: TextStyle(
                                  color: dialogContext.colors.white,
                                  fontWeight: FontWeight.w900)))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: ElevatedButton(
                          onPressed: () async {
                            final navigator = Navigator.of(dialogContext);
                            final messenger =
                                ScaffoldMessenger.of(dialogContext);
                            final ctx = dialogContext;
                            final planId = plan['id'];
                            setState(() => plans.remove(plan));
                            navigator.pop();
                            messenger.showSnackBar(SnackBar(
                                content:
                                    Text('Plan "${plan['name']}" eliminado'),
                                backgroundColor: ctx.colors.green));
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
                              backgroundColor: dialogContext.colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13))),
                          child: const Text('ELIMINAR',
                              style: TextStyle(fontWeight: FontWeight.w900)))),
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
                            : equipment.text.trim()
                      });
                    });
                    navigator.pop();
                    await _saveLocalData();
                    messenger.showSnackBar(SnackBar(
                        content: const Text('Rutina creada correctamente'),
                        backgroundColor: ctx.colors.green));
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
                    messenger.showSnackBar(SnackBar(
                        content: const Text('Rutina actualizada correctamente'),
                        backgroundColor: ctx.colors.green));
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
              Text('¿Eliminar "${routine['name']}"?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: dialogContext.colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              side: BorderSide(
                                  color: dialogContext.colors.border),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13))),
                          child: Text('CANCELAR',
                              style: TextStyle(
                                  color: dialogContext.colors.white,
                                  fontWeight: FontWeight.w900)))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: ElevatedButton(
                          onPressed: () async {
                            final navigator = Navigator.of(dialogContext);
                            final messenger =
                                ScaffoldMessenger.of(dialogContext);
                            final ctx = dialogContext;
                            setState(() => routines.remove(routine));
                            navigator.pop();
                            await _saveLocalData();
                            messenger.showSnackBar(SnackBar(
                                content: Text(
                                    'Rutina "${routine['name']}" eliminada'),
                                backgroundColor: ctx.colors.green));
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: dialogContext.colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13))),
                          child: const Text('ELIMINAR',
                              style: TextStyle(fontWeight: FontWeight.w900)))),
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
                        border: Border.all(color: dialogContext.colors.border)),
                    child: Row(children: [
                      Icon(Icons.fitness_center_rounded,
                          color: dialogContext.colors.red, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(routineName,
                              style: TextStyle(
                                  color: dialogContext.colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14))),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: dialogContext.colors.red
                                  .withValues(alpha: .15),
                              borderRadius: BorderRadius.circular(20)),
                          child: Text('${assignedIds.length} asignados',
                              style: TextStyle(
                                  color: dialogContext.colors.red,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900))),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Text('Toca un cliente para ASIGNAR o QUITAR esta rutina:',
                      style: TextStyle(
                          color: dialogContext.colors.muted, fontSize: 11)),
                  const SizedBox(height: 12),
                  if (activeMembers.isEmpty)
                    Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text('No hay clientes activos',
                            style:
                                TextStyle(color: dialogContext.colors.muted)))
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
                                        if (x['assignedRoutineId'] ==
                                            routineId) {
                                          count++;
                                        }
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
                                          'assigned_routine_id': null
                                        }).eq('id', mId);
                                      } catch (e) {
                                        debugPrint('⚠️ Error quitando: $e');
                                      }
                                    }
                                    await addActivity('RUTINA QUITADA',
                                        '$routineName ← $mName');
                                  } else {
                                    setState(() {
                                      m['assignedRoutine'] = routineName;
                                      m['assignedRoutineId'] = routineId;
                                      int count = 0;
                                      for (var x in members) {
                                        if (x['assignedRoutineId'] ==
                                            routineId) {
                                          count++;
                                        }
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
                                          'assigned_routine_id': routineId
                                        }).eq('id', mId);
                                      } catch (e) {
                                        debugPrint('⚠️ Error asignando: $e');
                                      }
                                    }
                                    await addActivity('RUTINA ASIGNADA',
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
                                              : dialogContext.colors.border)),
                                  child: Row(children: [
                                    CircleAvatar(
                                        radius: 18,
                                        backgroundColor: dialogContext
                                            .colors.red
                                            .withValues(alpha: .15),
                                        child: Text(initial,
                                            style: TextStyle(
                                                color: dialogContext.colors.red,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 14))),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Text(mName,
                                            style: TextStyle(
                                                color:
                                                    dialogContext.colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis)),
                                    Icon(
                                        hasIt
                                            ? Icons.check_circle_rounded
                                            : Icons.add_circle_outline_rounded,
                                        color: hasIt
                                            ? dialogContext.colors.green
                                            : dialogContext.colors.muted,
                                        size: 22),
                                  ]),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 20),
                  _button('CERRAR', dialogContext.colors.red, () {
                    Navigator.pop(dialogContext);
                    setState(() {});
                  }),
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
                      DropdownMenuItem(
                          value: 'Zona media', child: Text('Zona media')),
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
                        'level': level
                      });
                    });
                    navigator.pop();
                    await _saveLocalData();
                    messenger.showSnackBar(SnackBar(
                        content: const Text('Ejercicio creado correctamente'),
                        backgroundColor: ctx.colors.green));
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
    String muscle = exercise['muscle'] == 'Core'
        ? 'Zona media'
        : exercise['muscle'].toString();
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
                      DropdownMenuItem(
                          value: 'Zona media', child: Text('Zona media')),
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
                    messenger.showSnackBar(SnackBar(
                        content:
                            const Text('Ejercicio actualizado correctamente'),
                        backgroundColor: ctx.colors.green));
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
              Text('¿Eliminar "${exercise['name']}"?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: dialogContext.colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              side: BorderSide(
                                  color: dialogContext.colors.border),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13))),
                          child: Text('CANCELAR',
                              style: TextStyle(
                                  color: dialogContext.colors.white,
                                  fontWeight: FontWeight.w900)))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: ElevatedButton(
                          onPressed: () async {
                            final navigator = Navigator.of(dialogContext);
                            final messenger =
                                ScaffoldMessenger.of(dialogContext);
                            final ctx = dialogContext;
                            setState(() => exercises.remove(exercise));
                            navigator.pop();
                            await _saveLocalData();
                            messenger.showSnackBar(SnackBar(
                                content: Text(
                                    'Ejercicio "${exercise['name']}" eliminado'),
                                backgroundColor: ctx.colors.green));
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: dialogContext.colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13))),
                          child: const Text('ELIMINAR',
                              style: TextStyle(fontWeight: FontWeight.w900)))),
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
                        border: Border.all(color: dialogContext.colors.border)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.star_rounded,
                              color: dialogContext.colors.yellow, size: 18),
                          const SizedBox(width: 8),
                          Text('Rating',
                              style: TextStyle(
                                  color: dialogContext.colors.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                          const Spacer(),
                          Text(rating.toStringAsFixed(1),
                              style: TextStyle(
                                  color: dialogContext.colors.yellow,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900)),
                        ]),
                        Slider(
                            value: rating,
                            min: 1,
                            max: 5,
                            divisions: 40,
                            activeColor: dialogContext.colors.yellow,
                            inactiveColor: dialogContext.colors.border,
                            label: rating.toStringAsFixed(1),
                            onChanged: (v) => setDialogState(() => rating = v)),
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
                            : schedule.text.trim()
                      });
                    });
                    navigator.pop();
                    await _saveLocalData();
                    messenger.showSnackBar(SnackBar(
                        content: const Text('Entrenador creado correctamente'),
                        backgroundColor: ctx.colors.green));
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
                        border: Border.all(color: dialogContext.colors.border)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.star_rounded,
                              color: dialogContext.colors.yellow, size: 18),
                          const SizedBox(width: 8),
                          Text('Rating',
                              style: TextStyle(
                                  color: dialogContext.colors.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                          const Spacer(),
                          Text(rating.toStringAsFixed(1),
                              style: TextStyle(
                                  color: dialogContext.colors.yellow,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900)),
                        ]),
                        Slider(
                            value: rating,
                            min: 1,
                            max: 5,
                            divisions: 40,
                            activeColor: dialogContext.colors.yellow,
                            inactiveColor: dialogContext.colors.border,
                            label: rating.toStringAsFixed(1),
                            onChanged: (v) => setDialogState(() => rating = v)),
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
                    messenger.showSnackBar(SnackBar(
                        content:
                            const Text('Entrenador actualizado correctamente'),
                        backgroundColor: ctx.colors.green));
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
              Text('¿Eliminar a ${trainer['name']}?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: dialogContext.colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              side: BorderSide(
                                  color: dialogContext.colors.border),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13))),
                          child: Text('CANCELAR',
                              style: TextStyle(
                                  color: dialogContext.colors.white,
                                  fontWeight: FontWeight.w900)))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: ElevatedButton(
                          onPressed: () async {
                            final navigator = Navigator.of(dialogContext);
                            final messenger =
                                ScaffoldMessenger.of(dialogContext);
                            final ctx = dialogContext;
                            setState(() => trainers.remove(trainer));
                            navigator.pop();
                            await _saveLocalData();
                            messenger.showSnackBar(SnackBar(
                                content: Text('${trainer['name']} eliminado'),
                                backgroundColor: ctx.colors.green));
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: dialogContext.colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13))),
                          child: const Text('ELIMINAR',
                              style: TextStyle(fontWeight: FontWeight.w900)))),
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
                        border: Border.all(color: dialogContext.colors.border)),
                    child: Row(children: [
                      Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                              color: dialogContext.colors.red
                                  .withValues(alpha: .15),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: dialogContext.colors.red
                                      .withValues(alpha: .35))),
                          child: Icon(_iconFromCodePoint(selectedIcon),
                              color: dialogContext.colors.red, size: 26)),
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
                                  letterSpacing: 0.5))),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: Text('ICONO',
                          style: TextStyle(
                              color: dialogContext.colors.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2))),
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
                                  width: 2)),
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
                        'icon': selectedIcon
                      });
                    });
                    navigator.pop();
                    await _saveLocalData();
                    messenger.showSnackBar(SnackBar(
                        content:
                            const Text('Tipo de clase creado correctamente'),
                        backgroundColor: ctx.colors.green));
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
                        border: Border.all(color: dialogContext.colors.border)),
                    child: Row(children: [
                      Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                              color: dialogContext.colors.red
                                  .withValues(alpha: .15),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: dialogContext.colors.red
                                      .withValues(alpha: .35))),
                          child: Icon(_iconFromCodePoint(selectedIcon),
                              color: dialogContext.colors.red, size: 26)),
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
                                  letterSpacing: 0.5))),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: Text('ICONO',
                          style: TextStyle(
                              color: dialogContext.colors.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2))),
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
                                  width: 2)),
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
                    messenger.showSnackBar(SnackBar(
                        content: const Text('Tipo actualizado correctamente'),
                        backgroundColor: ctx.colors.green));
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
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              side: BorderSide(
                                  color: dialogContext.colors.border),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13))),
                          child: Text('CANCELAR',
                              style: TextStyle(
                                  color: dialogContext.colors.white,
                                  fontWeight: FontWeight.w900)))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: ElevatedButton(
                          onPressed: () async {
                            final navigator = Navigator.of(dialogContext);
                            final messenger =
                                ScaffoldMessenger.of(dialogContext);
                            final ctx = dialogContext;
                            setState(() => classTypes.remove(ct));
                            navigator.pop();
                            await _saveLocalData();
                            messenger.showSnackBar(SnackBar(
                                content: Text('Tipo "${ct['name']}" eliminado'),
                                backgroundColor: ctx.colors.green));
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: dialogContext.colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13))),
                          child: const Text('ELIMINAR',
                              style: TextStyle(fontWeight: FontWeight.w900)))),
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
                      return DropdownMenuItem(
                          value: value,
                          child: Text(_localizedClassType(value)));
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
                        'room': 'Sala A'
                      });
                    });
                    navigator.pop();
                    await _saveLocalData();
                    messenger.showSnackBar(SnackBar(
                        content: const Text('Clase creada correctamente'),
                        backgroundColor: ctx.colors.green));
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
                      return DropdownMenuItem(
                          value: value,
                          child: Text(_localizedClassType(value)));
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
                    messenger.showSnackBar(SnackBar(
                        content: const Text('Clase actualizada correctamente'),
                        backgroundColor: ctx.colors.green));
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
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              side: BorderSide(
                                  color: dialogContext.colors.border),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13))),
                          child: Text('CANCELAR',
                              style: TextStyle(
                                  color: dialogContext.colors.white,
                                  fontWeight: FontWeight.w900)))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: ElevatedButton(
                          onPressed: () async {
                            final navigator = Navigator.of(dialogContext);
                            final messenger =
                                ScaffoldMessenger.of(dialogContext);
                            final ctx = dialogContext;
                            setState(() => classes.remove(classItem));
                            navigator.pop();
                            await _saveLocalData();
                            messenger.showSnackBar(SnackBar(
                                content: Text(
                                    'Clase "${classItem['name']}" eliminada'),
                                backgroundColor: ctx.colors.green));
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: dialogContext.colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13))),
                          child: const Text('ELIMINAR',
                              style: TextStyle(fontWeight: FontWeight.w900)))),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _mobileDrawer() {
    final primaryColor = context.colors.green;
    final textWhite = context.colors.white;
    final textMuted = context.colors.muted;

    return Drawer(
      backgroundColor: context.colors.bg,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Row(
                children: [
                  Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                                color: primaryColor.withValues(alpha: 0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 5))
                          ]),
                      child: const Icon(Icons.bolt_rounded,
                          color: Colors.white, size: 30)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SYNTHETIX',
                            style: TextStyle(
                                color: textWhite,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1)),
                        const SizedBox(height: 2),
                        Text('GYM OS PRO',
                            style: TextStyle(
                                color: textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5)),
                      ],
                    ),
                  ),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: textMuted)),
                ],
              ),
            ),
            Divider(
                color: context.colors.border.withValues(alpha: 0.5), height: 1),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  _buildDrawerItem(
                      icon: Icons.grid_view_rounded,
                      title: 'Centro de operaciones',
                      subtitle: 'Resumen general del gimnasio',
                      color: Colors.blueAccent,
                      isSelected: _section == 0,
                      onTap: () {
                        _goToSection(0);
                        Navigator.pop(context);
                      }),
                  _buildDrawerItem(
                      icon: Icons.people_alt_rounded,
                      title: 'Clientes',
                      subtitle: 'Gestión de miembros',
                      color: Colors.greenAccent,
                      isSelected: _section == 1,
                      onTap: () {
                        _goToSection(1);
                        Navigator.pop(context);
                      }),
                  _buildDrawerItem(
                      icon: Icons.qr_code_scanner_rounded,
                      title: 'Acceso QR',
                      subtitle: 'Control de entradas y salidas',
                      color: Colors.cyanAccent,
                      isSelected: _section == 2,
                      onTap: () {
                        _goToSection(2);
                        Navigator.pop(context);
                      }),
                  _buildDrawerItem(
                      icon: Icons.card_membership_rounded,
                      title: 'Membresías',
                      subtitle: 'Planes y suscripciones',
                      color: Colors.orangeAccent,
                      isSelected: _section == 3,
                      onTap: () {
                        _goToSection(3);
                        Navigator.pop(context);
                      }),
                  _buildDrawerItem(
                      icon: Icons.payments_rounded,
                      title: 'Finanzas',
                      subtitle: 'Ingresos y estadísticas',
                      color: Colors.purpleAccent,
                      isSelected: _section == 4,
                      onTap: () {
                        _goToSection(4);
                        Navigator.pop(context);
                      }),
                  _buildDrawerItem(
                      icon: Icons.fitness_center_rounded,
                      title: 'Entrenamiento',
                      subtitle: 'Clases, rutinas y entrenadores',
                      color: Colors.pinkAccent,
                      isSelected: _section == 5,
                      onTap: () {
                        _goToSection(5);
                        Navigator.pop(context);
                      }),
                  _buildDrawerItem(
                      icon: Icons.notifications_active_rounded,
                      title: 'Alertas',
                      subtitle: 'Notificaciones pendientes',
                      color: Colors.redAccent,
                      isSelected: _section == 6,
                      badgeCount: alertCount(context) + renewalRequests.length,
                      onTap: () {
                        _goToSection(6);
                        Navigator.pop(context);
                      }),
                  _buildDrawerItem(
                      icon: Icons.history_rounded,
                      title: 'Historial de accesos',
                      subtitle: 'Entradas, salidas y bloqueos',
                      color: Colors.lightGreenAccent,
                      isSelected: _section == 8,
                      onTap: () {
                        _goToSection(8);
                        Navigator.pop(context);
                      }),
                  _buildDrawerItem(
                      icon: Icons.settings_rounded,
                      title: 'Configuración',
                      subtitle: 'Ajustes generales',
                      color: Colors.grey,
                      isSelected: _section == 7,
                      onTap: () {
                        _goToSection(7);
                        Navigator.pop(context);
                      }),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                          child: Divider(
                              color: context.colors.border
                                  .withValues(alpha: 0.5))),
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: Colors.orange, size: 14),
                            const SizedBox(width: 4),
                            Text('Ajustes de Sistema',
                                style: TextStyle(
                                    color: context.colors.muted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900))
                          ])),
                      Expanded(
                          child: Divider(
                              color: context.colors.border
                                  .withValues(alpha: 0.5))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDrawerItem(
                      icon: themeController.isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      title:
                          themeController.isDark ? 'Modo Claro' : 'Modo Oscuro',
                      subtitle: 'Cambiar la apariencia',
                      color: Colors.yellow,
                      onTap: () {
                        themeController.toggle();
                        Navigator.pop(context);
                      }),
                  _buildDrawerItem(
                      icon: Icons.logout_rounded,
                      title: 'Cerrar Sesión',
                      subtitle: 'Salir del sistema',
                      color: primaryColor,
                      isDanger: true,
                      onTap: () {
                        Navigator.pop(context);
                        confirmLogout();
                      }),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_rounded,
                      color: context.colors.green, size: 16),
                  const SizedBox(width: 8),
                  Text('Sistema Operativo v1.0',
                      style: TextStyle(
                          color: textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: context.colors.green,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color:
                                    context.colors.green.withValues(alpha: 0.5),
                                blurRadius: 6)
                          ])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
      {required IconData icon,
      required String title,
      required String subtitle,
      required Color color,
      required VoidCallback onTap,
      bool isSelected = false,
      bool isDanger = false,
      int badgeCount = 0}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.1)
                  : (isDanger
                      ? context.colors.red.withValues(alpha: 0.05)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isSelected
                      ? color.withValues(alpha: 0.3)
                      : (isDanger
                          ? context.colors.red.withValues(alpha: 0.2)
                          : Colors.transparent)),
            ),
            child: Row(
              children: [
                Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle),
                    child: Icon(icon,
                        color: isDanger ? context.colors.red : color,
                        size: 22)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              color: isDanger
                                  ? context.colors.red
                                  : context.colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                              color: context.colors.muted, fontSize: 11)),
                    ],
                  ),
                ),
                if (badgeCount > 0)
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: context.colors.red,
                          borderRadius: BorderRadius.circular(12)),
                      child: Text('$badgeCount',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900)))
                else
                  Icon(Icons.arrow_forward_ios_rounded,
                      color: context.colors.muted.withValues(alpha: 0.5),
                      size: 14),
              ],
            ),
          ),
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
                      : _content()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sidebar() {
    final items = [
      [Icons.grid_view_rounded, 'Centro de operaciones'],
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
                      borderRadius: BorderRadius.circular(13)),
                  child: const Icon(Icons.bolt_rounded,
                      color: Colors.white, size: 27)),
              const SizedBox(width: 12),
              Expanded(
                  child: Text('SYNTHETIX\nGYM OS PRO',
                      style: TextStyle(
                          color: context.colors.white,
                          fontSize: 15,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.3))),
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
                                    : Colors.transparent)),
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
                                            : FontWeight.w600))),
                            if (isAlerts && ac > 0)
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                      color: context.colors.red,
                                      borderRadius: BorderRadius.circular(20)),
                                  child: Text('$ac',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900))),
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
                    border: Border.all(color: context.colors.border)),
                child: Row(children: [
                  Icon(
                      themeController.isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      color: context.colors.red,
                      size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(
                          themeController.isDark ? 'Modo claro' : 'Modo oscuro',
                          style: TextStyle(
                              color: context.colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700))),
                ]),
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
                        color: context.colors.red.withValues(alpha: .30))),
                child: Row(children: [
                  Icon(Icons.logout_rounded,
                      color: context.colors.red, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text('CERRAR SESIÓN',
                          style: TextStyle(
                              color: context.colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5))),
                ]),
              ),
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

  Widget _clientStatCard({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
    VoidCallback? onTap,
    bool selected = false,
  }) {
    final card = Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: context.colors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              selected ? color.withValues(alpha: .55) : context.colors.border,
          width: selected ? 2 : 1.2,
        ),
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
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: card,
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
                height: 1,
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
                onTap: () => setState(() => clientFilter = 'TODOS'),
                selected: clientFilter == 'TODOS',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _clientStatCard(
                icon: Icons.check_circle_rounded,
                color: context.colors.green,
                value: '$totalActivos',
                label: 'Activos',
                onTap: () => setState(() => clientFilter = 'ACTIVOS'),
                selected: clientFilter == 'ACTIVOS',
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
                onTap: () => setState(() => clientFilter = 'POR VENCER'),
                selected: clientFilter == 'POR VENCER',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _clientStatCard(
                icon: Icons.block_rounded,
                color: context.colors.red,
                value: '$totalVencidos',
                label: 'Vencidos',
                onTap: () => setState(() => clientFilter = 'VENCIDOS'),
                selected: clientFilter == 'VENCIDOS',
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
                tooltip: 'WhatsApp del gimnasio',
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

  Future<void> _downloadGymQr() async {
    try {
      final image = await _qrScreenshotController.capture(pixelRatio: 3);
      if (image == null) {
        throw StateError('No se pudo generar la imagen del código QR.');
      }
      final blob = html.Blob([image], 'image/png');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..download = 'synthetix-acceso-qr.png'
        ..click();
      html.Url.revokeObjectUrl(url);
    } catch (error) {
      debugPrint('Error descargando el código QR: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo descargar el código QR: $error'),
          backgroundColor: context.colors.red,
        ),
      );
    }
  }

  Widget _qrCenter() {
    final code = qrToken.isEmpty ? 'SYNTHETIX-GYM' : qrToken;
    final expired = qrExpires.isBefore(DateTime.now()) && qrMode != 'FIJO';
    final qrColor = expired ? context.colors.red : context.colors.green;
    final expiryLabel = qrMode == 'FIJO'
        ? 'Sin vencimiento'
        : '${_formatMemberSince(qrExpires)} · ${_fmtTime(qrExpires)}';
    final remainingLabel = qrMode == 'FIJO' ? 'Acceso permanente' : qrTimeLeft;

    Widget infoCard(
      String label,
      String value,
      IconData icon,
      Color color,
    ) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        color: context.colors.muted,
                        fontSize: 11,
                      )),
                  const SizedBox(height: 4),
                  Text(value,
                      style: TextStyle(
                        color: context.colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      )),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final qrCard = _buildGlassCard(
          glowColor: qrColor,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.qr_code_2_rounded,
                      color: context.colors.green, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('CÓDIGO DE ACCESO DEL GIMNASIO',
                        style: TextStyle(
                          color: context.colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .6,
                        )),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: qrColor.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          expired ? Icons.error_rounded : Icons.circle,
                          size: 9,
                          color: qrColor,
                        ),
                        const SizedBox(width: 6),
                        Text(expired ? 'EXPIRADO' : 'ACTIVO',
                            style: TextStyle(
                              color: qrColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Center(
                child: Screenshot(
                  controller: _qrScreenshotController,
                  child: Container(
                    width: 330,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: qrColor.withValues(alpha: .20),
                          blurRadius: 36,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bolt_rounded,
                                color: context.colors.red, size: 19),
                            const SizedBox(width: 5),
                            const Text('SYNTHETIX GYM',
                                style: TextStyle(
                                  color: Color(0xFF111827),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.4,
                                )),
                          ],
                        ),
                        const SizedBox(height: 12),
                        QrImageView(
                          data: code,
                          size: 245,
                          backgroundColor: Colors.white,
                          errorCorrectionLevel: QrErrorCorrectLevel.H,
                        ),
                        const SizedBox(height: 10),
                        const Text('ESCANEA PARA VALIDAR EL ACCESO',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .7,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SelectableText(code,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .4,
                  )),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: _downloadGymQr,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Descargar PNG'),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.colors.green,
                      foregroundColor: context.colors.bg,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: showInsidePeople,
                    icon: const Icon(Icons.people_alt_rounded),
                    label: const Text('Ver personas dentro'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _goToSection(8),
                    icon: const Icon(Icons.history_rounded),
                    label: const Text('Ver historial'),
                  ),
                ],
              ),
            ],
          ),
        );

        final settingsCard = _buildGlassCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CONFIGURACIÓN DEL CÓDIGO',
                  style: TextStyle(
                    color: context.colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  )),
              const SizedBox(height: 6),
              Text('Define cuánto tiempo será válido el acceso.',
                  style: TextStyle(
                    color: context.colors.muted,
                    fontSize: 12,
                  )),
              const SizedBox(height: 18),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'DIARIO', label: Text('Diario')),
                  ButtonSegment(value: 'SEMANAL', label: Text('7 días')),
                  ButtonSegment(value: 'FIJO', label: Text('Permanente')),
                ],
                selected: {qrMode},
                onSelectionChanged: (selection) {
                  setState(() => qrMode = selection.first);
                  generateGymQr();
                },
              ),
              const SizedBox(height: 18),
              infoCard(
                  'Estado',
                  expired ? 'Requiere renovar' : 'Listo para usar',
                  Icons.verified_user_rounded,
                  qrColor),
              const SizedBox(height: 10),
              infoCard('Vigencia', expiryLabel, Icons.event_available_rounded,
                  context.colors.blue),
              const SizedBox(height: 10),
              infoCard('Tiempo restante', remainingLabel,
                  Icons.hourglass_bottom_rounded, context.colors.yellow),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: generateGymQr,
                  icon: const Icon(Icons.autorenew_rounded),
                  label: const Text('Generar nuevo código'),
                  style: FilledButton.styleFrom(
                    backgroundColor: context.colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ],
          ),
        );

        return SingleChildScrollView(
          padding: EdgeInsets.all(isWide ? 28 : 18),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1360),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Acceso QR',
                      style: TextStyle(
                        color: context.colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.6,
                      )),
                  const SizedBox(height: 6),
                  Text(
                      'Controla, comparte y valida el acceso de tus miembros desde un único lugar.',
                      style: TextStyle(
                        color: context.colors.muted,
                        fontSize: 14,
                      )),
                  const SizedBox(height: 22),
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: qrCard),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 4,
                          child: Column(
                            children: [
                              settingsCard,
                              const SizedBox(height: 14),
                              infoCard(
                                'Ocupación actual',
                                '$inside de $capacity personas',
                                Icons.groups_rounded,
                                context.colors.blue,
                              ),
                              const SizedBox(height: 10),
                              infoCard(
                                'Entradas de hoy',
                                '$todayEntries accesos autorizados',
                                Icons.login_rounded,
                                context.colors.green,
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  else ...[
                    qrCard,
                    const SizedBox(height: 14),
                    settingsCard,
                    const SizedBox(height: 10),
                    infoCard(
                      'Ocupación actual',
                      '$inside de $capacity personas',
                      Icons.groups_rounded,
                      context.colors.blue,
                    ),
                    const SizedBox(height: 10),
                    infoCard(
                      'Entradas de hoy',
                      '$todayEntries accesos autorizados',
                      Icons.login_rounded,
                      context.colors.green,
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildGlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: context.colors.blue, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Muestra este código en recepción para registrar accesos. '
                            'El modo diario se renueva automáticamente; el modo semanal '
                            'y el permanente conservan su vigencia configurada.',
                            style: TextStyle(
                              color: context.colors.muted,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _qrCenterMobile() => _qrCenter();

  Widget _plansPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('Planes',
                style: TextStyle(
                    color: context.colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900)),
          ),
          FilledButton.icon(
            onPressed: addPlan,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nuevo plan'),
          ),
        ]),
        const SizedBox(height: 18),
        ...plans.map((plan) => _buildGlassCard(
              margin: const EdgeInsets.only(bottom: 12),
              glowColor: context.colors.blue,
              onTap: () => editPlan(plan),
              child: Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(plan['name'].toString(),
                            style: TextStyle(
                                color: context.colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16)),
                        const SizedBox(height: 5),
                        Text('${plan['days']} días · ${plan['access']}',
                            style: TextStyle(color: context.colors.muted)),
                      ]),
                ),
                Text(formatPrice((plan['price'] as num).toDouble()),
                    style: TextStyle(
                        color: context.colors.blue,
                        fontSize: 18,
                        fontWeight: FontWeight.w900)),
              ]),
            )),
      ]),
    );
  }

  Widget _plansPageMobilePro() => _plansPage();

  DateTime? _transactionDate(Map<String, dynamic> transaction) {
    final value = transaction['created_at'];
    if (value is DateTime) return value.toLocal();
    if (value != null) return DateTime.tryParse(value.toString())?.toLocal();
    return null;
  }

  DateTime _financePeriodStart(DateTime now) {
    switch (financePeriod) {
      case 'SEMANA':
        return DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
      case 'AÑO':
        return DateTime(now.year);
      case 'MES':
      default:
        return DateTime(now.year, now.month);
    }
  }

  Widget _financePage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1000;
        final now = DateTime.now();
        final periodStart = _financePeriodStart(now);
        final periodTransactions = transactions.where((transaction) {
          final date = _transactionDate(transaction);
          return date != null &&
              !date.isBefore(periodStart) &&
              !date.isAfter(now);
        }).toList();
        final periodIncome = periodTransactions
            .where((transaction) => transaction['type'] == 'INGRESO')
            .fold<double>(
                0,
                (total, transaction) =>
                    total + (transaction['amount'] as num).toDouble());
        final periodExpenses = periodTransactions
            .where((transaction) => transaction['type'] == 'EGRESO')
            .fold<double>(
                0,
                (total, transaction) =>
                    total + (transaction['amount'] as num).abs().toDouble());
        final net = periodIncome - periodExpenses;
        final periodPayments = periodTransactions
            .where((transaction) => transaction['type'] == 'INGRESO')
            .length;
        final averagePayment =
            periodPayments == 0 ? 0.0 : periodIncome / periodPayments;
        final items = filteredTransactions.where((transaction) {
          final date = _transactionDate(transaction);
          return date != null &&
              !date.isBefore(periodStart) &&
              !date.isAfter(now);
        }).toList()
          ..sort((a, b) => (_transactionDate(b) ?? DateTime(0))
              .compareTo(_transactionDate(a) ?? DateTime(0)));

        final monthStarts = List.generate(6, (index) {
          final offset = 5 - index;
          return DateTime(now.year, now.month - offset);
        });
        final monthlyCashflow = monthStarts.map((month) {
          var monthIncome = 0.0;
          var monthExpenses = 0.0;
          for (final transaction in transactions) {
            final date = _transactionDate(transaction);
            if (date == null ||
                date.year != month.year ||
                date.month != month.month) {
              continue;
            }
            final amount = (transaction['amount'] as num).toDouble();
            if (transaction['type'] == 'INGRESO') monthIncome += amount;
            if (transaction['type'] == 'EGRESO') {
              monthExpenses += amount.abs();
            }
          }
          return {'income': monthIncome, 'expenses': monthExpenses};
        }).toList();
        final largestMonth = monthlyCashflow.fold<double>(0, (highest, month) {
          final total =
              (month['income'] as double) + (month['expenses'] as double);
          return total > highest ? total : highest;
        });
        final methodTotals = <String, double>{
          'EFECTIVO': 0,
          'TARJETA': 0,
          'TRANSFERENCIA': 0,
        };
        for (final transaction in periodTransactions
            .where((transaction) => transaction['type'] == 'INGRESO')) {
          final method = transaction['method']?.toString() ?? '';
          methodTotals[method] = (methodTotals[method] ?? 0) +
              (transaction['amount'] as num).toDouble();
        }
        final methods = [
          (
            'EFECTIVO',
            'Efectivo',
            Icons.payments_rounded,
            context.colors.green
          ),
          (
            'TARJETA',
            'Tarjeta',
            Icons.credit_card_rounded,
            context.colors.blue
          ),
          (
            'TRANSFERENCIA',
            'Transferencia',
            Icons.swap_horiz_rounded,
            context.colors.yellow
          ),
        ];
        final visibleItems = items.take(financeVisibleCount).toList();
        final financeActions = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: newExpense,
              icon: const Icon(Icons.remove_circle_outline_rounded),
              label: const Text('Registrar gasto'),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.red,
                side:
                    BorderSide(color: context.colors.red.withValues(alpha: .5)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              ),
            ),
            FilledButton.icon(
              onPressed: newPayment,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Registrar pago'),
              style: FilledButton.styleFrom(
                backgroundColor: context.colors.green,
                foregroundColor: context.colors.bg,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ],
        );

        final pageTitle = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Finanzas',
                style: TextStyle(
                  color: context.colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.6,
                )),
            const SizedBox(height: 6),
            Text(
                'Control financiero, ingresos y actividad de caja del gimnasio.',
                style: TextStyle(
                  color: context.colors.muted,
                  fontSize: 14,
                )),
          ],
        );

        Widget financeMetric(
          String label,
          String value,
          String detail,
          IconData icon,
          Color color,
        ) {
          return Container(
            width: isWide
                ? (constraints.maxWidth - 60) / 4
                : constraints.maxWidth > 640
                    ? (constraints.maxWidth - 16) / 2
                    : constraints.maxWidth,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: context.colors.panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const Spacer(),
                    Icon(Icons.trending_up_rounded,
                        color: color.withValues(alpha: .7), size: 18),
                  ],
                ),
                const SizedBox(height: 18),
                Text(label.toUpperCase(),
                    style: TextStyle(
                      color: context.colors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .7,
                    )),
                const SizedBox(height: 6),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    )),
                const SizedBox(height: 3),
                Text(detail,
                    style: TextStyle(
                      color: context.colors.muted,
                      fontSize: 11,
                    )),
              ],
            ),
          );
        }

        Widget panelTitle(String title, String subtitle, IconData icon) {
          return Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.colors.red.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: context.colors.red, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                          color: context.colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        )),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: TextStyle(
                          color: context.colors.muted,
                          fontSize: 11,
                        )),
                  ],
                ),
              ),
            ],
          );
        }

        final cashflowPanel = _buildGlassCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              panelTitle('Flujo de caja', 'Ingresos y egresos por mes',
                  Icons.stacked_bar_chart_rounded),
              const SizedBox(height: 20),
              if (largestMonth == 0)
                SizedBox(
                  height: 178,
                  child: Center(
                    child: Text('Aún no hay movimientos para graficar.',
                        style: TextStyle(color: context.colors.muted)),
                  ),
                )
              else
                SizedBox(
                  height: 178,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: List.generate(monthStarts.length, (index) {
                      final month = monthlyCashflow[index];
                      final monthIncome = month['income'] as double;
                      final monthExpenses = month['expenses'] as double;
                      final monthMax = math.max(monthIncome, monthExpenses);
                      final incomeHeight = 104 * monthIncome / largestMonth;
                      final expenseHeight = 104 * monthExpenses / largestMonth;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            children: [
                              SizedBox(
                                height: 22,
                                child: FittedBox(
                                  child: Text(
                                    formatPrice(monthIncome + monthExpenses),
                                    style: TextStyle(
                                      color: context.colors.muted,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        width: 11,
                                        height: monthMax == 0
                                            ? 3
                                            : incomeHeight.clamp(3, 104),
                                        decoration: BoxDecoration(
                                          color: context.colors.green,
                                          borderRadius:
                                              BorderRadius.circular(5),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        width: 11,
                                        height: monthMax == 0
                                            ? 3
                                            : expenseHeight.clamp(3, 104),
                                        decoration: BoxDecoration(
                                          color: context.colors.red,
                                          borderRadius:
                                              BorderRadius.circular(5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(_monthName(monthStarts[index].month),
                                  style: TextStyle(
                                    color: context.colors.muted,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  )),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  _financeLegend('Ingresos', context.colors.green),
                  _financeLegend('Egresos', context.colors.red),
                ],
              ),
            ],
          ),
        );

        final methodsPanel = _buildGlassCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              panelTitle('Métodos de pago', 'Distribución de los ingresos',
                  Icons.account_balance_wallet_rounded),
              const SizedBox(height: 22),
              ...methods.map((method) {
                final amount = methodTotals[method.$1] ?? 0;
                final ratio = periodIncome <= 0 ? 0.0 : amount / periodIncome;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(method.$3, color: method.$4, size: 18),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(method.$2,
                                style: TextStyle(
                                  color: context.colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                )),
                          ),
                          Text(formatPrice(amount),
                              style: TextStyle(
                                color: context.colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              )),
                        ],
                      ),
                      const SizedBox(height: 9),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: ratio.clamp(0, 1),
                          minHeight: 7,
                          backgroundColor: context.colors.border,
                          valueColor: AlwaysStoppedAnimation<Color>(method.$4),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );

        return SingleChildScrollView(
          padding: EdgeInsets.all(isWide ? 28 : 18),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (constraints.maxWidth >= 760)
                    Row(
                      children: [
                        Expanded(child: pageTitle),
                        financeActions,
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        pageTitle,
                        const SizedBox(height: 14),
                        financeActions,
                      ],
                    ),
                  const SizedBox(height: 22),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'SEMANA', label: Text('Semana')),
                        ButtonSegment(value: 'MES', label: Text('Mes')),
                        ButtonSegment(value: 'AÑO', label: Text('Año')),
                      ],
                      selected: {financePeriod},
                      onSelectionChanged: (selection) => setState(() {
                        financePeriod = selection.first;
                        financeVisibleCount = 12;
                      }),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      financeMetric(
                          'Ingresos',
                          formatPrice(periodIncome),
                          '$periodPayments pagos en el período',
                          Icons.south_west_rounded,
                          context.colors.green),
                      financeMetric(
                          'Egresos',
                          formatPrice(periodExpenses),
                          'Gastos registrados en el período',
                          Icons.north_east_rounded,
                          context.colors.red),
                      financeMetric(
                          'Balance neto',
                          formatPrice(net),
                          'Ingresos menos egresos',
                          Icons.account_balance_rounded,
                          net >= 0 ? context.colors.blue : context.colors.red),
                      financeMetric(
                          'Pago promedio',
                          formatPrice(averagePayment),
                          'Por cada ingreso registrado',
                          Icons.receipt_long_rounded,
                          context.colors.yellow),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: cashflowPanel),
                        const SizedBox(width: 16),
                        Expanded(flex: 4, child: methodsPanel),
                      ],
                    )
                  else ...[
                    cashflowPanel,
                    const SizedBox(height: 14),
                    methodsPanel,
                  ],
                  const SizedBox(height: 16),
                  _buildGlassCard(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        panelTitle(
                            'Libro de movimientos',
                            'Detalle de ingresos y egresos registrados',
                            Icons.receipt_long_rounded),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final filter in [
                              ('TODOS', 'Todos'),
                              ('INGRESOS', 'Ingresos'),
                              ('EGRESOS', 'Egresos'),
                            ])
                              ChoiceChip(
                                label: Text(filter.$2),
                                selected: transactionFilter == filter.$1,
                                onSelected: (_) => setState(() {
                                  transactionFilter = filter.$1;
                                  financeVisibleCount = 12;
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (visibleItems.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 30),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.receipt_long_outlined,
                                      color: context.colors.muted, size: 38),
                                  const SizedBox(height: 10),
                                  Text('No hay movimientos en este período.',
                                      style: TextStyle(
                                        color: context.colors.muted,
                                        fontSize: 13,
                                      )),
                                ],
                              ),
                            ),
                          )
                        else
                          ...visibleItems.map((item) {
                            final isExpense = item['type'] == 'EGRESO';
                            final method =
                                item['method']?.toString().toUpperCase() ?? '';
                            final methodLabel = switch (method) {
                              'EFECTIVO' => 'Efectivo',
                              'TARJETA' => 'Tarjeta',
                              'TRANSFERENCIA' => 'Transferencia',
                              _ => method.isEmpty ? 'Sin método' : method,
                            };
                            final date = _transactionDate(item)!;
                            final localOnly = item['localOnly'] == true;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 13),
                              decoration: BoxDecoration(
                                color: context.colors.panel,
                                borderRadius: BorderRadius.circular(14),
                                border:
                                    Border.all(color: context.colors.border),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: (isExpense
                                              ? context.colors.red
                                              : context.colors.green)
                                          .withValues(alpha: .12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isExpense
                                          ? Icons.arrow_upward_rounded
                                          : Icons.arrow_downward_rounded,
                                      color: isExpense
                                          ? context.colors.red
                                          : context.colors.green,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(item['name']?.toString() ??
                                            'Movimiento del gimnasio'),
                                        const SizedBox(height: 4),
                                        Text(
                                            '${item['concept'] ?? 'Sin concepto'} · $methodLabel · ${_formatMemberSince(date)}${localOnly ? ' · Solo en este dispositivo' : ''}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: context.colors.muted,
                                              fontSize: 11,
                                            )),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                      '${isExpense ? '−' : '+'}${formatPrice((item['amount'] as num).abs().toDouble())}',
                                      style: TextStyle(
                                        color: isExpense
                                            ? context.colors.red
                                            : context.colors.green,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                      )),
                                ],
                              ),
                            );
                          }),
                        if (items.length > visibleItems.length) ...[
                          Align(
                            alignment: Alignment.center,
                            child: Text(
                                'Mostrando ${visibleItems.length} de ${items.length} movimientos',
                                style: TextStyle(
                                  color: context.colors.muted,
                                  fontSize: 11,
                                )),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.center,
                            child: TextButton.icon(
                              onPressed: () =>
                                  setState(() => financeVisibleCount += 12),
                              icon: const Icon(Icons.expand_more_rounded),
                              label: const Text('Cargar más movimientos'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _financeLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
              color: context.colors.muted,
              fontSize: 10,
            )),
      ],
    );
  }

  Widget _trainingPage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 950;
        final assignedTotal = members
            .where((member) =>
                member['assignedRoutineId'] != null &&
                member['assignedRoutineId'].toString().isNotEmpty)
            .length;
        final activeMembers =
            members.where((member) => member['status'] == 'ACTIVO').length;
        final classCapacity = classes.fold<int>(
            0, (sum, item) => sum + (item['capacity'] as int));
        final enrolledTotal = classes.fold<int>(
            0, (sum, item) => sum + (item['enrolled'] as int));

        Widget statCard(
          String label,
          String value,
          String description,
          IconData icon,
          Color color,
        ) {
          return Container(
            width: isWide
                ? (constraints.maxWidth - 60) / 4
                : constraints.maxWidth > 640
                    ? (constraints.maxWidth - 16) / 2
                    : constraints.maxWidth,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: context.colors.panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(value,
                          style: TextStyle(
                            color: context.colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          )),
                      const SizedBox(height: 3),
                      Text(label,
                          style: TextStyle(
                            color: context.colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
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
              ],
            ),
          );
        }

        Widget routineCard(Map<String, dynamic> routine) {
          final assigned = members
              .where((member) =>
                  member['assignedRoutineId']?.toString() ==
                  routine['id']?.toString())
              .length;
          final levelColor = switch (routine['level']?.toString()) {
            'Principiante' => context.colors.green,
            'Intermedio' => context.colors.yellow,
            _ => context.colors.red,
          };
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: context.colors.panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: context.colors.red.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.fitness_center_rounded,
                          color: context.colors.red, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(routine['name'].toString(),
                              style: TextStyle(
                                color: context.colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              )),
                          const SizedBox(height: 4),
                          Text(
                              '${routine['duration']} min · ${routine['exercises']} ejercicios',
                              style: TextStyle(
                                color: context.colors.muted,
                                fontSize: 11,
                              )),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Acciones de rutina',
                      onSelected: (value) {
                        if (value == 'assign') showAssignRoutineDialog(routine);
                        if (value == 'edit') editRoutine(routine);
                        if (value == 'delete') deleteRoutine(routine);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 'assign', child: Text('Asignar a clientes')),
                        PopupMenuItem(value: 'edit', child: Text('Editar')),
                        PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _trainingTag(routine['level'].toString(), levelColor),
                    _trainingTag(
                        routine['equipment']?.toString() ?? 'Sin equipamiento',
                        context.colors.blue),
                    _trainingTag('$assigned asignados', context.colors.green),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => showAssignRoutineDialog(routine),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
                    label: const Text('Gestionar asignaciones'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(color: context.colors.border),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        Widget exerciseCard(Map<String, dynamic> exercise) {
          return Container(
            margin: const EdgeInsets.only(bottom: 9),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(
              color: context.colors.panel,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.colors.blue.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.sports_gymnastics_rounded,
                      color: context.colors.blue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exercise['name'].toString(),
                          style: TextStyle(
                            color: context.colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          )),
                      const SizedBox(height: 4),
                      Text(
                          '${_localizedMuscleGroup(exercise['muscle'].toString())} · ${exercise['sets']} series · ${exercise['reps']} repeticiones · ${(exercise['weight'] as num).toString()} kg',
                          style: TextStyle(
                            color: context.colors.muted,
                            fontSize: 10,
                          )),
                    ],
                  ),
                ),
                _trainingTag(exercise['level'].toString(), context.colors.blue),
                PopupMenuButton<String>(
                  tooltip: 'Acciones del ejercicio',
                  onSelected: (value) {
                    if (value == 'edit') editExercise(exercise);
                    if (value == 'delete') deleteExercise(exercise);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
              ],
            ),
          );
        }

        Widget classCard(Map<String, dynamic> classItem) {
          final capacity = classItem['capacity'] as int;
          final enrolled = classItem['enrolled'] as int;
          final fullness = capacity == 0 ? 0.0 : enrolled / capacity;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: context.colors.panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.colors.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: context.colors.yellow.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _iconFromCodePoint(classTypes.firstWhere(
                          (type) => type['name'] == classItem['type'],
                          orElse: () => classTypes.first,
                        )['icon'] as int),
                        color: context.colors.yellow,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(classItem['name'].toString(),
                              style: TextStyle(
                                color: context.colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              )),
                          const SizedBox(height: 4),
                          Text(
                              '${_localizedClassType(classItem['type'].toString())} · ${classItem['day']} · ${classItem['time']}',
                              style: TextStyle(
                                color: context.colors.muted,
                                fontSize: 11,
                              )),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Editar clase',
                      onPressed: () => editClass(classItem),
                      icon: Icon(Icons.edit_rounded,
                          color: context.colors.yellow, size: 19),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded,
                        color: context.colors.muted, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          '${classItem['trainer']} · ${classItem['room']} · ${classItem['duration']} min',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.colors.muted,
                            fontSize: 10,
                          )),
                    ),
                    Text('$enrolled / $capacity',
                        style: TextStyle(
                          color: context.colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        )),
                  ],
                ),
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: fullness.clamp(0, 1),
                    minHeight: 6,
                    backgroundColor: context.colors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(fullness >= .9
                        ? context.colors.red
                        : context.colors.yellow),
                  ),
                ),
              ],
            ),
          );
        }

        final pageAction = trainingTab == 0
            ? FilledButton.icon(
                onPressed: addRoutine,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Crear rutina'),
              )
            : trainingTab == 1
                ? FilledButton.icon(
                    onPressed: addExercise,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Agregar ejercicio'),
                  )
                : FilledButton.icon(
                    onPressed: addClass,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Programar clase'),
                  );

        return SingleChildScrollView(
          padding: EdgeInsets.all(isWide ? 28 : 18),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Entrenamiento',
                                style: TextStyle(
                                  color: context.colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -.6,
                                )),
                            const SizedBox(height: 6),
                            Text(
                                'Programa rutinas, organiza ejercicios y administra las clases del gimnasio.',
                                style: TextStyle(
                                  color: context.colors.muted,
                                  fontSize: 14,
                                )),
                          ],
                        ),
                      ),
                      if (isWide) pageAction,
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      statCard(
                          'Rutinas',
                          '${routines.length}',
                          'Planes de entrenamiento',
                          Icons.view_list_rounded,
                          context.colors.red),
                      statCard(
                          'Ejercicios',
                          '${exercises.length}',
                          'En la biblioteca',
                          Icons.fitness_center_rounded,
                          context.colors.blue),
                      statCard(
                          'Clientes asignados',
                          '$assignedTotal',
                          'De $activeMembers miembros activos',
                          Icons.assignment_ind_rounded,
                          context.colors.green),
                      statCard(
                          'Clases programadas',
                          '${classes.length}',
                          '$enrolledTotal inscritos de $classCapacity cupos',
                          Icons.calendar_month_rounded,
                          context.colors.yellow),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(
                          value: 0,
                          icon: Icon(Icons.view_list_rounded),
                          label: Text('Rutinas')),
                      ButtonSegment(
                          value: 1,
                          icon: Icon(Icons.fitness_center_rounded),
                          label: Text('Ejercicios')),
                      ButtonSegment(
                          value: 2,
                          icon: Icon(Icons.calendar_month_rounded),
                          label: Text('Clases')),
                    ],
                    selected: {trainingTab},
                    onSelectionChanged: (selection) =>
                        setState(() => trainingTab = selection.first),
                  ),
                  if (!isWide) ...[
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: pageAction),
                  ],
                  const SizedBox(height: 16),
                  _buildGlassCard(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      trainingTab == 0
                                          ? 'Biblioteca de rutinas'
                                          : trainingTab == 1
                                              ? 'Biblioteca de ejercicios'
                                              : 'Programación de clases',
                                      style: TextStyle(
                                        color: context.colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                      )),
                                  const SizedBox(height: 4),
                                  Text(
                                      trainingTab == 0
                                          ? 'Crea programas y asígnalos a tus miembros.'
                                          : trainingTab == 1
                                              ? 'Administra ejercicios por grupo muscular y nivel.'
                                              : 'Consulta horarios, aforo y entrenadores asignados.',
                                      style: TextStyle(
                                        color: context.colors.muted,
                                        fontSize: 12,
                                      )),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (trainingTab == 0)
                          if (routines.isEmpty)
                            _trainingEmptyState(
                                'Todavía no hay rutinas. Crea la primera para comenzar.',
                                Icons.fitness_center_rounded)
                          else
                            ...routines.map(routineCard)
                        else if (trainingTab == 1) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final muscle in [
                                'TODOS',
                                ...exercises
                                    .map((exercise) =>
                                        exercise['muscle'].toString())
                                    .toSet()
                              ])
                                ChoiceChip(
                                  label: Text(muscle == 'TODOS'
                                      ? 'Todos'
                                      : _localizedMuscleGroup(muscle)),
                                  selected: exerciseFilter == muscle,
                                  onSelected: (_) =>
                                      setState(() => exerciseFilter = muscle),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...exercises
                              .where((exercise) =>
                                  exerciseFilter == 'TODOS' ||
                                  exercise['muscle'].toString() ==
                                      exerciseFilter)
                              .map(exerciseCard),
                        ] else if (classes.isEmpty)
                          _trainingEmptyState(
                              'No hay clases programadas. Agrega la primera al calendario.',
                              Icons.calendar_month_rounded)
                        else
                          ...classes.map(classCard),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _trainingTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Text(label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          )),
    );
  }

  String _localizedMuscleGroup(String muscle) =>
      muscle == 'Core' ? 'Zona media' : muscle;

  String _localizedClassType(String type) {
    switch (type.toUpperCase()) {
      case 'SPINNING':
        return 'Ciclismo indoor';
      case 'CROSSFIT':
        return 'Acondicionamiento funcional';
      default:
        if (type.isEmpty) return type;
        return type[0].toUpperCase() + type.substring(1).toLowerCase();
    }
  }

  Widget _trainingEmptyState(String message, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 16),
      child: Center(
        child: Column(
          children: [
            Icon(icon, color: context.colors.muted, size: 42),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.colors.muted,
                  fontSize: 13,
                )),
          ],
        ),
      ),
    );
  }

  Widget _alertsPage() {
    final allAlerts = activeAlerts(context);
    final alerts = filteredAlerts(context);
    final counts = <String, int>{
      'TODAS': allAlerts.length,
      'PENDIENTES':
          allAlerts.where((alert) => alert['type'] == 'PENDIENTE').length,
      'VENCIDAS': allAlerts.where((alert) => alert['type'] == 'VENCIDA').length,
      'POR VENCER':
          allAlerts.where((alert) => alert['type'] == 'POR VENCER').length,
      'INFO': allAlerts.where((alert) => alert['type'] == 'AFORO').length,
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Centro de alertas',
                  style: TextStyle(
                      color: context.colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                  'Revisa pendientes, vencimientos y niveles de ocupación desde un solo lugar.',
                  style: TextStyle(color: context.colors.muted, fontSize: 14)),
              const SizedBox(height: 22),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _alertSummaryCard(
                    'Alertas activas',
                    '${counts['TODAS']}',
                    Icons.notifications_active_rounded,
                  ),
                  _alertSummaryCard(
                    'Requieren atención',
                    '${counts['PENDIENTES']! + counts['VENCIDAS']!}',
                    Icons.priority_high_rounded,
                  ),
                  _alertSummaryCard(
                    'Próximos vencimientos',
                    '${counts['POR VENCER']}',
                    Icons.event_available_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text('Notificaciones',
                        style: TextStyle(
                            color: context.colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                  ),
                  Text('${alerts.length} resultados',
                      style:
                          TextStyle(color: context.colors.muted, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: counts.entries.map((entry) {
                  final selected = alertFilter == entry.key;
                  return ChoiceChip(
                    label: Text('${entry.key} · ${entry.value}'),
                    selected: selected,
                    selectedColor: context.colors.green.withValues(alpha: .18),
                    labelStyle: TextStyle(
                      color: selected
                          ? context.colors.green
                          : context.colors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                    side: BorderSide(
                      color: selected
                          ? context.colors.green.withValues(alpha: .45)
                          : context.colors.border,
                    ),
                    onSelected: (_) => setState(() => alertFilter = entry.key),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              if (alerts.isEmpty)
                _buildGlassCard(
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      children: [
                        Icon(Icons.task_alt_rounded,
                            color: context.colors.green, size: 34),
                        const SizedBox(height: 10),
                        Text(
                          allAlerts.isEmpty
                              ? 'Todo está al día'
                              : 'No hay alertas en esta categoría',
                          style: TextStyle(
                              color: context.colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          allAlerts.isEmpty
                              ? 'Las nuevas notificaciones aparecerán aquí.'
                              : 'Prueba con otro filtro para ver más resultados.',
                          style: TextStyle(color: context.colors.muted),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...alerts.map((alert) {
                  final severity = alert['color'] as Color;
                  final member = alert['member'];
                  return _buildGlassCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: severity.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(alert['icon'] as IconData,
                              color: severity, size: 21),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(alert['title'].toString(),
                                      style: TextStyle(
                                          color: context.colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800)),
                                  _statusChip(
                                      alert['type'].toString(), severity),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(alert['subtitle'].toString(),
                                  style: TextStyle(
                                      color: context.colors.muted,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                        if (member is Map)
                          IconButton(
                            tooltip: 'Ver ficha del cliente',
                            onPressed: () => showClientDetail(
                                Map<String, dynamic>.from(member)),
                            icon: Icon(Icons.open_in_new_rounded,
                                color: context.colors.green),
                          ),
                        IconButton(
                          tooltip: 'Descartar alerta',
                          onPressed: () => dismissAlert(alert['id'].toString()),
                          icon: Icon(Icons.close_rounded,
                              color: context.colors.muted),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _alertSummaryCard(String title, String value, IconData icon) {
    return SizedBox(
      width: 250,
      child: _buildGlassCard(
        padding: const EdgeInsets.all(18),
        glowColor: context.colors.border,
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: context.colors.green.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: context.colors.green, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style:
                          TextStyle(color: context.colors.muted, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(value,
                      style: TextStyle(
                          color: context.colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _alertsPageMobile() => _alertsPage();

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
      fillColor: ctx.colors.panel2.withValues(alpha: 0.8),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: ctx.colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: ctx.colors.green, width: 1.5),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        ),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w900, letterSpacing: .5)),
      ),
    );
  }

  Widget _dialog({
    required String title,
    required Widget child,
    Color? accent,
  }) {
    return Dialog(
      backgroundColor: context.colors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: context.colors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(
                  width: 8,
                  height: 30,
                  decoration: BoxDecoration(
                      color: accent ?? context.colors.green,
                      borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        color: context.colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900)),
              ),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: context.colors.muted)),
            ]),
            const SizedBox(height: 18),
            child,
          ]),
        ),
      ),
    );
  }

  void showAccessScanner() {
    if (loggedClient != null) {
      openClientQrScanner();
    } else {
      _goToSection(2);
    }
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: context.colors.panel2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: context.colors.blue.withValues(alpha: .45),
                    width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_add_alt_1_rounded,
                      color: context.colors.blue, size: 20),
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
                child: Text(
                  'No hay planes disponibles',
                  style: TextStyle(color: context.colors.muted),
                ),
              ),
            )
          else
            ...plans.map((plan) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _planSelectorCard(plan),
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
                  width: 1.5),
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
                        width: 2),
                  ),
                  child: Icon(Icons.check_circle_rounded,
                      color: context.colors.green, size: 50),
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
                      color: context.colors.muted, fontSize: 13, height: 1.5),
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
            border: Border.all(color: color.withValues(alpha: .35), width: 1.5),
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
            border: Border.all(color: color.withValues(alpha: .35), width: 1.5),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: .08), blurRadius: 25),
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
                  border: Border.all(color: color.withValues(alpha: .35)),
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
              Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
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
        contentPadding:
            const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
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
    final name = plan['name']?.toString() ?? '';
    final price = (plan['price'] as num?)?.toDouble() ?? 0.0;
    final days = plan['days']?.toString() ?? '';
    final access = plan['access']?.toString() ?? '';
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
                      color: context.colors.red.withValues(alpha: .35)),
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
          foregroundColor: darkText ? Colors.black : Colors.white,
          elevation: 0,
          disabledBackgroundColor: color.withValues(alpha: .4),
          disabledForegroundColor: Colors.white.withValues(alpha: .5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
    final status = client['status']?.toString() ?? 'ACTIVO';
    return Scaffold(
      backgroundColor: context.colors.bg,
      appBar: AppBar(
        title: const Text('Mi membresía'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: confirmLogout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildGlassCard(
            glowColor: context.colors.green,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hola, $name',
                  style: TextStyle(
                      color: context.colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Text('Plan ${client['plan']} · ${client['expiry']}',
                  style: TextStyle(color: context.colors.muted)),
              const SizedBox(height: 8),
              Text(status.toUpperCase(),
                  style: TextStyle(
                      color: status == 'ACTIVO'
                          ? context.colors.green
                          : context.colors.red,
                      fontWeight: FontWeight.w900)),
            ]),
          ),
          const SizedBox(height: 14),
          _buildGlassCard(
            glowColor: context.colors.green,
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: context.colors.green.withValues(alpha: 0.45),
                        blurRadius: 25),
                  ],
                ),
                child: QrImageView(
                  data: client['qrCode']?.toString() ?? '',
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text('QR personal de acceso',
                  style: TextStyle(color: context.colors.white)),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> showInsidePeople() async {
    await loadInsidePeople();
    if (!mounted) return;
    await _showTodayStatSheet(type: 'DENTRO');
  }

  Future<void> showDaySummary() async {
    await loadTodaySummary(forDate: summarySelectedDate);
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final date = summarySelectedDate;
            final isToday = date.year == DateTime.now().year &&
                date.month == DateTime.now().month &&
                date.day == DateTime.now().day;
            final dateLabel = isToday
                ? 'HOY · ${date.day} ${_monthName(date.month)}'
                : '${date.day} ${_monthName(date.month)} ${date.year}';

            Widget summaryAction(
              String label,
              int value,
              Color color,
              IconData icon,
              String type,
            ) {
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showTodayStatSheet(type: type);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      color: sheetContext.colors.panel,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: sheetContext.colors.border),
                    ),
                    child: Column(
                      children: [
                        Icon(icon, color: color, size: 22),
                        const SizedBox(height: 8),
                        Text('$value',
                            style: TextStyle(
                              color: sheetContext.colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            )),
                        const SizedBox(height: 4),
                        Text(label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: sheetContext.colors.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            )),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Container(
              margin: EdgeInsets.only(
                  top: MediaQuery.of(sheetContext).padding.top + 40),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              decoration: BoxDecoration(
                color: sheetContext.colors.bg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color:
                              sheetContext.colors.muted.withValues(alpha: .4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('RESUMEN DEL DÍA',
                                  style: TextStyle(
                                    color: sheetContext.colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: .8,
                                  )),
                              const SizedBox(height: 4),
                              Text(dateLabel,
                                  style: TextStyle(
                                    color: sheetContext.colors.muted,
                                    fontSize: 12,
                                  )),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Elegir fecha',
                          onPressed: () async {
                            await _pickHistoryDate();
                            if (mounted) setSheetState(() {});
                          },
                          icon: Icon(Icons.calendar_month_rounded,
                              color: sheetContext.colors.blue),
                        ),
                        IconButton(
                          tooltip: 'Actualizar',
                          onPressed: () async {
                            await loadTodaySummary(
                                forDate: summarySelectedDate);
                            if (mounted) setSheetState(() {});
                          },
                          icon: Icon(Icons.refresh_rounded,
                              color: sheetContext.colors.green),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        summaryAction(
                            'Dentro ahora',
                            inside,
                            sheetContext.colors.green,
                            Icons.people_alt_rounded,
                            'DENTRO'),
                        const SizedBox(width: 10),
                        summaryAction(
                            'Entradas',
                            todayEntries,
                            sheetContext.colors.blue,
                            Icons.login_rounded,
                            'ENTRADAS'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        summaryAction(
                            'Salidas',
                            todayExits,
                            sheetContext.colors.yellow,
                            Icons.logout_rounded,
                            'SALIDAS'),
                        const SizedBox(width: 10),
                        summaryAction(
                            'Bloqueados',
                            todayBlocked,
                            sheetContext.colors.red,
                            Icons.block_rounded,
                            'BLOQUEADOS'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: sheetContext.colors.panel,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: sheetContext.colors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.payments_rounded,
                              color: sheetContext.colors.green),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text('Ingresos del día',
                                style: TextStyle(
                                  color: sheetContext.colors.muted,
                                  fontSize: 12,
                                )),
                          ),
                          Text(formatPrice(todayIncome),
                              style: TextStyle(
                                color: sheetContext.colors.green,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _mobile() {
    final canLeaveApp = _canLeaveApp();
    return PopScope(
      canPop: canLeaveApp,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _goBackInApp();
      },
      child: Scaffold(
        key: _scaffoldKey,
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
            _sectionTitle(),
            style: TextStyle(
              color: context.colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Aforo en vivo',
              icon: Icon(Icons.people_alt_rounded, color: context.colors.green),
              onPressed: showInsidePeople,
            ),
            IconButton(
              tooltip: 'Resumen del día',
              icon: Icon(Icons.insights_rounded, color: context.colors.blue),
              onPressed: showDaySummary,
            ),
            if (_section != 0)
              IconButton(
                tooltip: 'Inicio',
                icon: Icon(Icons.home_rounded, color: context.colors.red),
                onPressed: () {
                  _sectionHistory.clear();
                  setState(() => _section = 0);
                },
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: context.colors.border),
          ),
        ),
        body: loadingData
            ? Center(
                child: CircularProgressIndicator(color: context.colors.red))
            : _content(),
      ),
    );
  }

  Widget _currencyPage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth =
            (constraints.maxWidth - 48).clamp(0.0, 1360.0).toDouble();
        final columns = contentWidth >= 1100 ? 2 : 1;
        final cardWidth = columns == 2 ? (contentWidth - 20) / 2 : contentWidth;

        Widget section(String title, Widget child) => SizedBox(
              width: cardWidth,
              child: _card(title: title, child: child),
            );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1360),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Configuración del gimnasio',
                      style: TextStyle(
                          color: context.colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                      'Administra la operación, la seguridad y las preferencias de tu plataforma.',
                      style:
                          TextStyle(color: context.colors.muted, fontSize: 14)),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    children: [
                      section(
                        'Aforo máximo',
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Define la capacidad y controla el porcentaje de ocupación del gimnasio.',
                              style: TextStyle(
                                  color: context.colors.muted,
                                  fontSize: 12,
                                  height: 1.45),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _capacityController,
                                    keyboardType: TextInputType.number,
                                    style:
                                        TextStyle(color: context.colors.white),
                                    decoration: _inputDecoration(
                                      context,
                                      'Personas permitidas',
                                      prefixIcon: Icons.people_alt_rounded,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                FilledButton(
                                  onPressed: () async {
                                    final value = int.tryParse(
                                        _capacityController.text.trim());
                                    if (value == null || value <= 0) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Ingresa una capacidad mayor que cero.'),
                                        ),
                                      );
                                      return;
                                    }
                                    setState(() => capacity = value);
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    await prefs.setInt('capacity', value);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Aforo actualizado a $value personas.'),
                                      ),
                                    );
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: context.colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 16),
                                  ),
                                  child: const Text('Guardar'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _settingsInfoRow(
                              Icons.groups_rounded,
                              'Ocupación actual',
                              '$inside de $capacity personas',
                            ),
                          ],
                        ),
                      ),
                      section(
                        'Apariencia',
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Elige el modo de visualización para trabajar con mayor comodidad.',
                              style: TextStyle(
                                  color: context.colors.muted,
                                  fontSize: 12,
                                  height: 1.45),
                            ),
                            const SizedBox(height: 12),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                themeController.isDark
                                    ? 'Modo oscuro'
                                    : 'Modo claro',
                                style: TextStyle(color: context.colors.white),
                              ),
                              subtitle: Text(
                                'Cambiar el tema de toda la plataforma',
                                style: TextStyle(color: context.colors.muted),
                              ),
                              value: themeController.isDark,
                              activeColor: context.colors.green,
                              onChanged: (_) => themeController.toggle(),
                            ),
                          ],
                        ),
                      ),
                      section(
                        'Contacto del gimnasio',
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Este número se usa para abrir WhatsApp desde las fichas de clientes.',
                              style: TextStyle(
                                  color: context.colors.muted,
                                  fontSize: 12,
                                  height: 1.45),
                            ),
                            const SizedBox(height: 12),
                            _GymPhoneField(
                              initialValue: gymPhone,
                              onChanged: (value) =>
                                  setState(() => gymPhone = value),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () async {
                                  await _saveLocalData();
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Número de contacto guardado.')),
                                  );
                                },
                                icon: const Icon(Icons.save_rounded),
                                label: const Text('Guardar número'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: context.colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      section(
                        'Seguridad del administrador',
                        _ChangePinSection(
                          adminPin: adminPin,
                          onPinChanged: (newPin) async {
                            setState(() => adminPin = newPin);
                            await _saveLocalData();
                          },
                        ),
                      ),
                      section(
                        'Moneda principal',
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Los importes de pagos y reportes se mostrarán en esta moneda.',
                              style: TextStyle(
                                  color: context.colors.muted,
                                  fontSize: 12,
                                  height: 1.45),
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              value: selectedCurrency,
                              dropdownColor: context.colors.panel,
                              decoration: _inputDecoration(
                                  context, 'Selecciona una moneda'),
                              items: availableCurrencies
                                  .map((currency) => DropdownMenuItem(
                                        value: currency['code'],
                                        child: Text(
                                            '${currency['code']} · ${currency['name']}'),
                                      ))
                                  .toList(),
                              onChanged: (value) async {
                                if (value == null) return;
                                setState(() => selectedCurrency = value);
                                await _saveLocalData();
                              },
                            ),
                          ],
                        ),
                      ),
                      section(
                        'Conversión y tasas',
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('Mostrar conversión',
                                  style:
                                      TextStyle(color: context.colors.white)),
                              subtitle: Text(
                                  'Mostrar el equivalente en bolívares.',
                                  style:
                                      TextStyle(color: context.colors.muted)),
                              value: showConversion,
                              activeColor: context.colors.green,
                              onChanged: (value) async {
                                setState(() => showConversion = value);
                                await _saveLocalData();
                              },
                            ),
                            const SizedBox(height: 8),
                            _RateField(
                              label: '1 USD = bolívares',
                              initialValue: usdToVes,
                              onChanged: (value) async {
                                setState(() => usdToVes = value);
                                await _saveLocalData();
                              },
                            ),
                            const SizedBox(height: 10),
                            _RateField(
                              label: '1 EUR = bolívares',
                              initialValue: eurToVes,
                              onChanged: (value) async {
                                setState(() => eurToVes = value);
                                await _saveLocalData();
                              },
                            ),
                            const SizedBox(height: 10),
                            _RateField(
                              label: '1 COP = bolívares',
                              initialValue: copToVes,
                              onChanged: (value) async {
                                setState(() => copToVes = value);
                                await _saveLocalData();
                              },
                            ),
                          ],
                        ),
                      ),
                      section(
                        'Exportar información',
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Descarga los datos de clientes o el historial de accesos para revisarlos en una hoja de cálculo.',
                              style: TextStyle(
                                  color: context.colors.muted,
                                  fontSize: 12,
                                  height: 1.45),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _exportMembersCsv,
                                icon: const Icon(Icons.groups_rounded),
                                label:
                                    const Text('Descargar lista de clientes'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: context.colors.green,
                                  side: BorderSide(
                                      color: context.colors.green
                                          .withValues(alpha: .55)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _settingsInfoRow(
                              Icons.date_range_rounded,
                              'Periodo de accesos',
                              '${_formatDate(accessHistoryRange.start)} - ${_formatDate(accessHistoryRange.end)}',
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _pickAccessHistoryRange,
                                icon: const Icon(Icons.edit_calendar_rounded),
                                label: const Text('Cambiar periodo'),
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: loadingAccessHistory
                                    ? null
                                    : _downloadAccessHistoryCsv,
                                icon: const Icon(Icons.download_rounded),
                                label: Text(loadingAccessHistory
                                    ? 'Preparando descarga...'
                                    : 'Descargar historial de accesos'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: context.colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () async {
                        await _saveLocalData();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Configuración guardada correctamente.')),
                        );
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Guardar configuración'),
                      style: FilledButton.styleFrom(
                        backgroundColor: context.colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _settingsInfoRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.panel2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.colors.green, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(color: context.colors.muted, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: TextStyle(
                    color: context.colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAccessHistoryCsv() async {
    if (!await _loadAccessHistory() || !mounted) return;
    if (accessHistory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay registros para exportar.')),
      );
      return;
    }
    _exportAccessHistoryCsv(allTypes: true);
  }

  void _exportMembersCsv() {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('La descarga CSV está disponible en web.')),
      );
      return;
    }
    if (members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay clientes para exportar.')),
      );
      return;
    }

    final rows = <String>[
      [
        'Nombre',
        'Cédula',
        'Teléfono',
        'Plan',
        'Estado',
        'Vencimiento',
        'Miembro desde',
        'Visitas',
        'Total pagado',
        'Última visita',
        'Código QR',
      ].map(_csvCell).join(','),
      ...members.map((member) => [
            member['name'],
            member['cedula'],
            member['phone'],
            member['plan'],
            member['status'],
            member['expiry'],
            member['memberSince'],
            member['attendance'],
            member['totalPaid'],
            member['lastVisit'],
            member['qrCode'],
          ].map(_csvCell).join(',')),
    ];
    final blob =
        html.Blob(['\ufeff${rows.join('\r\n')}'], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'lista_clientes.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  void showNotifications() => _goToSection(6);

  Future<bool> _loadAccessHistory() async {
    setState(() => loadingAccessHistory = true);
    try {
      final start = DateTime(
        accessHistoryRange.start.year,
        accessHistoryRange.start.month,
        accessHistoryRange.start.day,
      );
      final end = DateTime(
        accessHistoryRange.end.year,
        accessHistoryRange.end.month,
        accessHistoryRange.end.day,
      ).add(const Duration(days: 1));
      final rows = await Supabase.instance.client
          .from('checkins')
          .select(
              'member_id, type, authorized, reason, created_at, members(name, plan)')
          .gte('created_at', start.toUtc().toIso8601String())
          .lt('created_at', end.toUtc().toIso8601String())
          .order('created_at', ascending: false);

      final loaded = rows.map<Map<String, dynamic>>((row) {
        final member = row['members'];
        final createdAt =
            DateTime.tryParse(row['created_at'].toString())?.toLocal();
        final authorized = row['authorized'] ?? true;
        final type = authorized == false
            ? 'BLOQUEADO'
            : (row['type'] ?? '').toString().toUpperCase();
        return {
          'memberId': row['member_id']?.toString() ?? '',
          'name':
              member is Map ? (member['name'] ?? 'Sin nombre') : 'Sin nombre',
          'plan': member is Map ? (member['plan'] ?? '—') : '—',
          'type': type,
          'reason': row['reason']?.toString() ?? '',
          'createdAt': createdAt ?? DateTime.now(),
        };
      }).toList();

      if (!mounted) return false;
      setState(() => accessHistory = loaded);
      return true;
    } catch (e) {
      debugPrint('Error cargando historial de accesos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cargar el historial: $e')),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => loadingAccessHistory = false);
    }
  }

  List<Map<String, dynamic>> get filteredAccessHistory {
    if (accessHistoryType == 'TODOS') return accessHistory;
    return accessHistory
        .where((record) => record['type'] == accessHistoryType)
        .toList();
  }

  Future<void> _pickAccessHistoryRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: accessHistoryRange,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: context.colors.green,
            onPrimary: Colors.black,
            surface: context.colors.panel,
            onSurface: context.colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (range == null) return;
    setState(() => accessHistoryRange = range);
    await _loadAccessHistory();
  }

  String _csvCell(Object? value) =>
      '"${value.toString().replaceAll('"', '""')}"';

  void _exportAccessHistoryCsv({bool allTypes = false}) {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('La descarga CSV está disponible en web.')),
      );
      return;
    }
    final records = allTypes ? accessHistory : filteredAccessHistory;
    final rows = <String>[
      ['Fecha', 'Hora', 'Cliente', 'Plan', 'Tipo', 'Detalle']
          .map(_csvCell)
          .join(','),
      ...records.map((record) {
        final date = record['createdAt'] as DateTime;
        return [
          _formatDate(date),
          _fmtTime(date),
          record['name'],
          record['plan'],
          record['type'],
          record['reason'],
        ].map(_csvCell).join(',');
      }),
    ];
    final blob =
        html.Blob(['\ufeff${rows.join('\r\n')}'], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'historial_accesos.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Widget _accessHistoryPage() {
    final records = filteredAccessHistory;
    final rangeLabel =
        '${_formatDate(accessHistoryRange.start)} - ${_formatDate(accessHistoryRange.end)}';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Historial de accesos',
                        style: TextStyle(
                            color: context.colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text('$rangeLabel · ${records.length} registros',
                        style: TextStyle(color: context.colors.muted)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: () async {
                  await _loadAccessHistory();
                },
                icon: Icon(Icons.refresh_rounded, color: context.colors.white),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                onPressed: _exportAccessHistoryCsv,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Exportar CSV'),
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.green,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _pickAccessHistoryRange,
                icon: const Icon(Icons.calendar_month_rounded),
                label: Text(rangeLabel),
              ),
              DropdownButton<String>(
                value: accessHistoryType,
                dropdownColor: context.colors.panel,
                style: TextStyle(color: context.colors.white),
                items: const [
                  DropdownMenuItem(value: 'TODOS', child: Text('Todos')),
                  DropdownMenuItem(value: 'ENTRADA', child: Text('Entradas')),
                  DropdownMenuItem(value: 'SALIDA', child: Text('Salidas')),
                  DropdownMenuItem(
                      value: 'BLOQUEADO', child: Text('Bloqueados')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => accessHistoryType = value);
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (loadingAccessHistory)
            const Center(child: CircularProgressIndicator())
          else if (records.isEmpty)
            _buildGlassCard(
              child: SizedBox(
                width: double.infinity,
                child: Text('No hay accesos para los filtros seleccionados.',
                    style: TextStyle(color: context.colors.muted)),
              ),
            )
          else
            ...records.map((record) {
              final type = record['type'] as String;
              final color = type == 'ENTRADA'
                  ? context.colors.green
                  : type == 'SALIDA'
                      ? context.colors.blue
                      : context.colors.red;
              final createdAt = record['createdAt'] as DateTime;
              return _buildGlassCard(
                margin: const EdgeInsets.only(bottom: 10),
                glowColor: color,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  children: [
                    Icon(
                        type == 'ENTRADA'
                            ? Icons.login_rounded
                            : type == 'SALIDA'
                                ? Icons.logout_rounded
                                : Icons.block_rounded,
                        color: color),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(record['name'].toString(),
                              style: TextStyle(
                                  color: context.colors.white,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text('${record['plan']} · ${record['reason']}',
                              style: TextStyle(
                                  color: context.colors.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(type,
                            style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(
                            '${_formatDate(createdAt)} · ${_fmtTime(createdAt)}',
                            style: TextStyle(
                                color: context.colors.muted, fontSize: 11)),
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

  Widget _content() {
    final isMobile = MediaQuery.of(context).size.width < 850;
    if (_section == 8) return _accessHistoryPage();
    if (_section == 1) return _clientsPage();
    if (_section == 2) {
      return Stack(
        children: [
          isMobile ? _qrCenterMobile() : _qrCenter(),
          Positioned(
            right: 20,
            bottom: 20,
            child: FilledButton.icon(
              onPressed: () => _goToSection(8),
              icon: const Icon(Icons.history_rounded),
              label: const Text('Historial'),
              style: FilledButton.styleFrom(
                backgroundColor: context.colors.green,
                foregroundColor: Colors.black,
              ),
            ),
          ),
        ],
      );
    }
    if (_section == 3) {
      return isMobile ? _plansPageMobilePro() : _plansPage();
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
      return Stack(
        children: [
          AdminHomeMobile(
            inside: inside,
            capacity: capacity,
            income: totalIncome,
            activeMembers: activeCount,
            expiringSoon: expiringCount,
            expired: expiredCount,
            activities: activities,
            notificationCount: ac,
            adminName: 'SYNTHETIX',
            onScan: showAccessScanner,
            onNewPayment: newPayment,
            onNewMember: addMember,
            onOpenNotifications: showNotifications,
            onOpenMore: () => _goToSection(8),
            onOpenMemberships: () => _goToSection(3),
            onOpenClients: () => _goToSection(1),
            onOpenFinance: () => _goToSection(4),
          ),
          if (lastAccessAlert != null)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                tween: Tween(begin: -100, end: 0),
                builder: (context, value, child) {
                  return Transform.translate(
                      offset: Offset(0, value), child: child);
                },
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                        color: (lastAccessAlert!['color'] as Color)
                            .withValues(alpha: .95),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: (lastAccessAlert!['color'] as Color)
                                  .withValues(alpha: .4),
                              blurRadius: 20,
                              offset: const Offset(0, 8))
                        ]),
                    child: Row(
                      children: [
                        Icon(lastAccessAlert!['icon'] as IconData,
                            color: Colors.white, size: 32),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(lastAccessAlert!['title'] as String,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1)),
                              const SizedBox(height: 4),
                              Text(lastAccessAlert!['name'] as String,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                        IconButton(
                            onPressed: () =>
                                setState(() => lastAccessAlert = null),
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }
    return _dashboardContent();
  }

  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadLocalData();
      final validQr = qrToken.isNotEmpty && qrExpires.isAfter(DateTime.now());
      if (!validQr) {
        generateGymQr();
      } else {
        _scheduleDailyQrRefresh();
      }
      _capacityController.text = capacity.toString();
      if (mounted) setState(() => loadingData = false);
      _syncWithSupabase();
    });
  }

  @override
  void dispose() {
    _aforoTimer?.cancel();
    _qrRefreshTimer?.cancel();
    _summaryTimer?.cancel();
    _alertTimer?.cancel();
    searchController.dispose();
    pinController.dispose();
    clientCedulaController.dispose();
    regNameController.dispose();
    regCedulaController.dispose();
    regPhoneController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 850;
    if (currentRole == UserRole.none) return _loginScreen();
    if (currentRole == UserRole.client) return _clientHome();
    if (isMobile) return _mobile();
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: _desktop(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CLASES Y WIDGETS AUXILIARES (FUERA DE LA CLASE PRINCIPAL)
// ═══════════════════════════════════════════════════════════════════

class _OccupancyPainter extends CustomPainter {
  final double percentage;
  final Color trackColor;
  final Color progressColor;
  _OccupancyPainter(
      {required this.percentage,
      required this.trackColor,
      required this.progressColor});
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
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, sweepAngle, false, progressPaint);
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
    final values = data.where((value) => value.isFinite).toList();
    if (values.isEmpty || size.width <= 0 || size.height <= 0) return;
    const inset = 3.0;
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = maxValue - minValue;
    final usableHeight = math.max(1.0, size.height - inset * 2);
    final stepX = values.length == 1 ? 0.0 : size.width / (values.length - 1);

    double yFor(double value) {
      if (range == 0) return size.height / 2;
      return inset + (maxValue - value) / range * usableHeight;
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: .35),
            color.withValues(alpha: .0)
          ]).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    final path = Path();
    final fillPath = Path();
    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = yFor(values[i]);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    if (values.length > 1) {
      fillPath.lineTo(size.width, size.height);
      fillPath.close();
      canvas.drawPath(fillPath, fillPaint);
    } else {
      canvas.drawCircle(
        Offset(size.width / 2, yFor(values.single)),
        3,
        Paint()..color = color,
      );
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MiniChartPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.color != color;
}

class AnimatedBentoChart extends StatelessWidget {
  final Color color;
  final List<double> data;
  const AnimatedBentoChart({
    super.key,
    required this.color,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final values = data.where((value) => value.isFinite).toList();
    if (values.isEmpty) {
      return Center(
        child: Text('Sin datos disponibles para este gráfico.',
            style: TextStyle(color: context.colors.muted, fontSize: 12)),
      );
    }
    final lowest = values.reduce(math.min);
    final highest = values.reduce(math.max);
    final range = highest - lowest;
    final verticalPadding =
        range == 0 ? math.max(1.0, highest.abs() * .15) : range * .12;
    final spots = <FlSpot>[
      for (var index = 0; index < data.length; index++)
        if (data[index].isFinite) FlSpot(index.toDouble(), data[index]),
    ];

    return LineChart(
      LineChartData(
        minY: lowest - verticalPadding,
        maxY: highest + verticalPadding,
        minX: 0,
        maxX: math.max(1, data.length - 1).toDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.white.withValues(alpha: 0.07), strokeWidth: 1),
        ),
        titlesData: const FlTitlesData(
          show: true,
          leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false, reservedSize: 0)),
          rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false, reservedSize: 0)),
          topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false, reservedSize: 0)),
          bottomTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false, reservedSize: 0)),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 3,
            dotData: FlDotData(
              show: spots.length == 1,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                radius: 3,
                color: color,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.35),
                  color.withValues(alpha: 0.01),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }
}

class _BentoChartPainter extends CustomPainter {
  final Color color;
  final double progress;
  _BentoChartPainter({required this.color, required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final path = Path();
    final points = [
      Offset(0, size.height * 0.8),
      Offset(size.width * 0.2, size.height * 0.5),
      Offset(size.width * 0.4, size.height * 0.6),
      Offset(size.width * 0.6, size.height * 0.2),
      Offset(size.width * 0.8, size.height * 0.4),
      Offset(size.width, size.height * 0.1),
    ];
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    final pathMetrics = path.computeMetrics();
    for (var metric in pathMetrics) {
      final extractPath = metric.extractPath(0, metric.length * progress);
      canvas.drawPath(extractPath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BentoChartPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _RateField extends StatefulWidget {
  final String label;
  final double initialValue;
  final ValueChanged<double> onChanged;
  const _RateField(
      {required this.label,
      required this.initialValue,
      required this.onChanged});
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
            borderSide: BorderSide(color: context.colors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(color: context.colors.red, width: 1.5)),
      ),
    );
  }
}

class _GymPhoneField extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;
  const _GymPhoneField({required this.initialValue, required this.onChanged});
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
            borderSide: BorderSide(color: context.colors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(color: context.colors.red, width: 1.5)),
      ),
    );
  }
}

class _ChangePinSection extends StatefulWidget {
  final String adminPin;
  final Future<void> Function(String newPin) onPinChanged;
  const _ChangePinSection({required this.adminPin, required this.onPinChanged});
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
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: const Text('PIN actual incorrecto'),
          backgroundColor: ctx.colors.red));
      return;
    }
    if (!RegExp(r'^\d{4}$').hasMatch(newPin)) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: const Text('El nuevo PIN debe tener exactamente 4 dígitos'),
          backgroundColor: ctx.colors.yellow));
      return;
    }
    if (newPin != confirm) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: const Text('Los PIN nuevos no coinciden'),
          backgroundColor: ctx.colors.red));
      return;
    }
    if (newPin == current) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: const Text('El nuevo PIN debe ser distinto al actual'),
          backgroundColor: ctx.colors.yellow));
      return;
    }
    await widget.onPinChanged(newPin);
    _currentPinCtrl.clear();
    _newPinCtrl.clear();
    _confirmPinCtrl.clear();
    if (mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: const Text('✅ PIN actualizado correctamente'),
          backgroundColor: ctx.colors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cambia el PIN de acceso del administrador.',
            style: TextStyle(color: context.colors.muted, fontSize: 11)),
        const SizedBox(height: 16),
        _pinField(
            controller: _currentPinCtrl,
            label: 'PIN actual',
            icon: Icons.lock_outline_rounded),
        const SizedBox(height: 10),
        _pinField(
            controller: _newPinCtrl,
            label: 'Nuevo PIN (4 dígitos)',
            icon: Icons.lock_open_rounded),
        const SizedBox(height: 10),
        _pinField(
            controller: _confirmPinCtrl,
            label: 'Confirmar nuevo PIN',
            icon: Icons.verified_user_rounded),
        const SizedBox(height: 16),
        SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
                onPressed: _updatePin,
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('ACTUALIZAR PIN',
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))))),
        const SizedBox(height: 12),
        Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: context.colors.yellow.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: context.colors.yellow.withValues(alpha: .30))),
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
                          fontWeight: FontWeight.w500)))
            ])),
      ],
    );
  }

  Widget _pinField(
      {required TextEditingController controller,
      required String label,
      required IconData icon}) {
    return TextField(
      controller: controller,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: 4,
      style: TextStyle(
          color: context.colors.white,
          fontSize: 16,
          letterSpacing: 8,
          fontWeight: FontWeight.w900),
      decoration: InputDecoration(
        counterText: '',
        labelText: label,
        labelStyle: TextStyle(
            color: context.colors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0),
        prefixIcon: Icon(icon, color: context.colors.red, size: 20),
        filled: true,
        fillColor: context.colors.panel2,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.colors.border, width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.colors.red, width: 2)),
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
  const _ClientProfilePage(
      {required this.member,
      required this.formatPrice,
      required this.onEdit,
      required this.onDelete,
      required this.transactions,
      required this.onWhatsApp});

  Color _statusColor(BuildContext c) {
    final s = member['status'].toString();
    if (s == 'ACTIVO') return c.colors.green;
    if (s == 'POR VENCER') return c.colors.yellow;
    return c.colors.red;
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
        transactions.where((t) => t['name'] == name).take(8).toList();
    final statusColor = _statusColor(context);

    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(children: [
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_rounded,
                        color: context.colors.white, size: 22)),
                const Spacer(),
                IconButton(
                    onPressed: () => _showActions(context),
                    icon: Icon(Icons.more_horiz_rounded,
                        color: context.colors.white, size: 24)),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: statusColor.withValues(alpha: .35),
                                    width: 1.5)),
                            alignment: Alignment.center,
                            child: Text(initial,
                                style: TextStyle(
                                    color: statusColor,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900))),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: TextStyle(
                                      color: context.colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -.3),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Row(children: [
                                Icon(Icons.phone_rounded,
                                    color: context.colors.muted, size: 12),
                                const SizedBox(width: 4),
                                Flexible(
                                    child: Text(member['phone'].toString(),
                                        style: TextStyle(
                                            color: context.colors.muted,
                                            fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis)),
                                const SizedBox(width: 10),
                                Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                        color:
                                            statusColor.withValues(alpha: .12),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: statusColor.withValues(
                                                alpha: .40))),
                                    child: Text(member['status'].toString(),
                                        style: TextStyle(
                                            color: statusColor,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: .5))),
                              ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                          color: context.colors.panel,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: context.colors.border)),
                      child: Row(children: [
                        _kpi(attendance.toString(), 'Asistencias',
                            context.colors.red),
                        Container(
                            width: 1, height: 36, color: context.colors.border),
                        _kpi(payments.toString(), 'Pagos',
                            context.colors.yellow),
                        Container(
                            width: 1, height: 36, color: context.colors.border),
                        _kpi(formatPrice(totalPaid), 'Total',
                            context.colors.green),
                      ]),
                    ),
                    const SizedBox(height: 20),
                    _sectionCard(context,
                        title: 'Detalles de membresía',
                        children: [
                          _infoRow('Plan', member['plan'].toString(), context),
                          _infoRow(
                              'Vence', member['expiry'].toString(), context),
                          _infoRow('Miembro desde',
                              member['memberSince'].toString(), context),
                          _infoRow('Última visita',
                              member['lastVisit'].toString(), context,
                              isLast: true),
                        ]),
                    if (routineName.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _sectionCard(context,
                          title: 'Rutina asignada',
                          children: [
                            Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                    color: context.colors.red
                                        .withValues(alpha: .08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: context.colors.red
                                            .withValues(alpha: .30))),
                                child: Row(children: [
                                  Icon(Icons.fitness_center_rounded,
                                      color: context.colors.red, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: Text(routineName,
                                          style: TextStyle(
                                              color: context.colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800)))
                                ])),
                          ]),
                    ],
                    const SizedBox(height: 16),
                    _sectionCard(context, title: 'QR de acceso', children: [
                      Center(
                          child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: context.colors.green
                                          .withValues(alpha: 0.48),
                                      blurRadius: 26,
                                      spreadRadius: 2,
                                    ),
                                  ]),
                              child: QrImageView(
                                  data: member['qrCode'].toString(),
                                  size: 150,
                                  backgroundColor: Colors.white))),
                      const SizedBox(height: 10),
                      Center(
                          child: Text(member['qrCode'].toString(),
                              style: TextStyle(
                                  color: context.colors.muted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1),
                              textAlign: TextAlign.center)),
                    ]),
                    const SizedBox(height: 16),
                    _sectionCard(context,
                        title: 'Historial de pagos',
                        children: memberTx.isEmpty
                            ? [
                                Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    child: Text('Sin pagos registrados',
                                        style: TextStyle(
                                            color: context.colors.muted,
                                            fontSize: 12)))
                              ]
                            : memberTx
                                .map((t) => _paymentRow(t, context))
                                .toList()),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                  color: context.colors.bg,
                  border:
                      Border(top: BorderSide(color: context.colors.border))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (member['status'].toString().toUpperCase() !=
                      'ACTIVO') ...[
                    SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              onEdit();
                            },
                            icon: const Icon(Icons.attach_money_rounded,
                                size: 24),
                            label: Text('COBRAR Y ACTIVAR (${member['plan']})',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 14)),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: context.colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))))),
                    const SizedBox(height: 12),
                  ],
                  Row(children: [
                    Expanded(
                        child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              Future.microtask(() => onEdit());
                            },
                            icon: Icon(Icons.edit_rounded,
                                color: context.colors.yellow, size: 16),
                            label: Text('EDITAR',
                                style: TextStyle(
                                    color: context.colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(color: context.colors.border),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: ElevatedButton.icon(
                            onPressed: onWhatsApp,
                            icon: const FaIcon(FontAwesomeIcons.whatsapp,
                                size: 16),
                            label: const Text('WHATSAPP',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: context.colors.green,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))))),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpi(String value, String label, Color color) {
    return Expanded(
        child: Column(children: [
      Text(value,
          style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      const SizedBox(height: 4),
      Text(label,
          style: TextStyle(
              color: color.withValues(alpha: .75),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: .5))
    ]));
  }

  Widget _sectionCard(BuildContext context,
      {required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: context.colors.bg.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(18),
          border:
              Border.all(color: context.colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 8)),
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.toUpperCase(),
            style: TextStyle(
                color: context.colors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2)),
        const SizedBox(height: 12),
        ...children
      ]),
    );
  }

  Widget _infoRow(String label, String value, BuildContext context,
      {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(children: [
        Expanded(
            flex: 4,
            child: Text(label,
                style: TextStyle(color: context.colors.muted, fontSize: 12))),
        Expanded(
            flex: 6,
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: context.colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700))),
      ]),
    );
  }

  Widget _paymentRow(Map<String, dynamic> t, BuildContext context) {
    final method = t['method'].toString();
    final amount = (t['amount'] as num).toDouble();
    final date = t['date'].toString();
    Color c = context.colors.green;
    IconData ic = Icons.payments_rounded;
    if (method == 'TARJETA') {
      c = context.colors.blue;
      ic = Icons.credit_card_rounded;
    } else if (method == 'TRANSFERENCIA') {
      c = context.colors.yellow;
      ic = Icons.swap_horiz_rounded;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: context.colors.panel2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.colors.border)),
      child: Row(children: [
        Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
                color: c.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(9)),
            child: Icon(ic, color: c, size: 15)),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(method,
              style: TextStyle(
                  color: context.colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800)),
          Text(date, style: TextStyle(color: context.colors.muted, fontSize: 9))
        ])),
        Text(formatPrice(amount),
            style: TextStyle(
                color: context.colors.green,
                fontSize: 12,
                fontWeight: FontWeight.w900)),
      ]),
    );
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.panel,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                    borderRadius: BorderRadius.circular(2))),
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
                }),
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
                }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ═══════════════════════════════════════════════════════════
// COLORES
// ═══════════════════════════════════════════════════════════

const Color kBg = Color(0xFF0B1118);
const Color kPanel = Color(0xFF121B24);
const Color kPanel2 = Color(0xFF192631);
const Color kBorder = Color(0xFF293944);
const Color kRed = Color(0xFFC96B72);
const Color kYellow = Color(0xFFC09A56);
const Color kGreen = Color(0xFF168F84);
const Color kWhite = Color(0xFFF1F6F7);
const Color kMuted = Color(0xFF99AAB1);

// ═══════════════════════════════════════════════════════════
// PERFIL DEL CLIENTE
// ═══════════════════════════════════════════════════════════

class ClientProfileScreen extends StatefulWidget {
  final String memberId;

  const ClientProfileScreen({super.key, required this.memberId});

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  bool _loading = true;
  Map<String, dynamic>? _member;
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _checkins = [];
  bool _isInside = false;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([
      _loadMember(),
      _loadClasses(),
      _loadPayments(),
      _loadCheckins(),
    ]);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadMember() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('members')
          .select()
          .eq('id', widget.memberId)
          .maybeSingle();

      if (response == null) return;

      if (!mounted) return;
      setState(() {
        _member = {
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
          'isInside': response['is_inside'] ?? false,
        };
        _isInside = response['is_inside'] == true;
      });
    } catch (e) {
      debugPrint('❌ Error loading member: $e');
    }
  }

  Future<void> _loadClasses() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('classes')
          .select()
          .order('day', ascending: true)
          .order('time', ascending: true);

      final loaded = <Map<String, dynamic>>[];
      for (final row in response) {
        loaded.add({
          'id': row['id'],
          'name': row['name'] ?? '',
          'type': row['type'] ?? '',
          'day': row['day'] ?? '',
          'time': row['time'] ?? '',
          'trainer': row['trainer'] ?? '',
          'capacity': row['capacity'] ?? 20,
          'enrolled': row['enrolled'] ?? 0,
        });
      }

      if (!mounted) return;
      setState(() => _classes = loaded);
    } catch (e) {
      debugPrint('❌ Error loading classes: $e');
    }
  }

  Future<void> _loadPayments() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('payments')
          .select()
          .eq('member_id', widget.memberId)
          .order('created_at', ascending: false)
          .limit(20);

      final loaded = <Map<String, dynamic>>[];
      for (final row in response) {
        final createdAt = DateTime.tryParse(
              row['created_at'].toString(),
            ) ??
            DateTime.now();
        loaded.add({
          'amount': (row['amount'] as num?)?.toDouble() ?? 0.0,
          'method': row['method'] ?? 'EFECTIVO',
          'date': _formatDate(createdAt),
        });
      }

      if (!mounted) return;
      setState(() => _payments = loaded);
    } catch (e) {
      debugPrint('❌ Error loading payments: $e');
    }
  }

  Future<void> _loadCheckins() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('checkins')
          .select()
          .eq('member_id', widget.memberId)
          .gte(
            'created_at',
            DateTime.now()
                .subtract(const Duration(days: 30))
                .toUtc()
                .toIso8601String(),
          )
          .order('created_at', ascending: false);

      final loaded = <Map<String, dynamic>>[];
      for (final row in response) {
        final createdAt = DateTime.tryParse(
              row['created_at'].toString(),
            ) ??
            DateTime.now();
        loaded.add({
          'type': row['type'] ?? 'ENTRADA',
          'date': _formatDateTime(createdAt),
          'createdAt': createdAt,
        });
      }

      if (!mounted) return;
      setState(() => _checkins = loaded);
    } catch (e) {
      debugPrint('❌ Error loading checkins: $e');
    }
  }

  String _formatDate(DateTime d) {
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
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  String _formatDateTime(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  DateTime? _parseProfileDate(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;

    final isoDate = DateTime.tryParse(text);
    if (isoDate != null) return isoDate;

    final numericDate =
        RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$').firstMatch(text);
    if (numericDate != null) {
      return DateTime(
        int.parse(numericDate.group(3)!),
        int.parse(numericDate.group(2)!),
        int.parse(numericDate.group(1)!),
      );
    }

    const monthNumbers = {
      'ENE': 1,
      'FEB': 2,
      'MAR': 3,
      'ABR': 4,
      'MAY': 5,
      'JUN': 6,
      'JUL': 7,
      'AGO': 8,
      'SEP': 9,
      'OCT': 10,
      'NOV': 11,
      'DIC': 12,
    };
    final spanishDate =
        RegExp(r'^(\d{1,2})\s+([A-ZÁÉÍÓÚ]{3})\s+(\d{4})$', caseSensitive: false)
            .firstMatch(text);
    if (spanishDate == null) return null;
    final month = monthNumbers[spanishDate.group(2)!.toUpperCase()];
    if (month == null) return null;
    return DateTime(
      int.parse(spanishDate.group(3)!),
      month,
      int.parse(spanishDate.group(1)!),
    );
  }

  int get _visitsLast30Days {
    return _checkins.where((checkin) {
      final date = checkin['createdAt'];
      return checkin['type'].toString().toUpperCase() == 'ENTRADA' &&
          date is DateTime;
    }).length;
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    final initials = parts.take(2).map((part) => part[0].toUpperCase()).join();
    return initials.isEmpty ? '?' : initials;
  }

  String _paymentMethodLabel(Object? method) {
    switch (method?.toString().trim().toUpperCase()) {
      case 'EFECTIVO':
        return 'Efectivo';
      case 'TARJETA':
        return 'Tarjeta';
      case 'TRANSFERENCIA':
        return 'Transferencia';
      case 'PAGO MÓVIL':
      case 'PAGO MOVIL':
        return 'Pago móvil';
      default:
        final value = method?.toString().trim() ?? '';
        return value.isEmpty ? 'Método no especificado' : value;
    }
  }

  String _classTypeLabel(Object? type) {
    switch (type?.toString().trim().toUpperCase()) {
      case 'SPINNING':
        return 'Ciclismo indoor';
      case 'CROSSFIT':
        return 'Acondicionamiento funcional';
      case 'YOGA':
        return 'Yoga';
      case 'PILATES':
        return 'Pilates';
      default:
        return type?.toString().trim() ?? '';
    }
  }

  // ═══════════════════════════════════════════════════════════
  // GETTERS DE ESTADO (usados por varios widgets)
  // ═══════════════════════════════════════════════════════════

  String get status {
    if (_member == null) return 'DESCONOCIDO';
    return _member!['status'].toString();
  }

  Color get _statusColor {
    if (_member == null) return kMuted;
    final s = _member!['status'].toString().toUpperCase();
    if (s == 'ACTIVO') return kGreen;
    if (s == 'POR VENCER') return kYellow;
    if (s == 'PENDIENTE PAGO') return kYellow;
    return kRed;
  }

  bool get _canEnterGym {
    if (_member == null) return false;
    final s = _member!['status'].toString().toUpperCase();
    return s == 'ACTIVO' || s == 'POR VENCER';
  }

  // ═══════════════════════════════════════════════════════════
  // ESCANEAR QR DEL GYM
  // ═══════════════════════════════════════════════════════════

  Future<void> _scanGymQr() async {
    if (!_canEnterGym) {
      _showSnack(
        '⛔ Tu membresía no está activa. Contacta al administrador.',
        kRed,
      );
      return;
    }

    if (_isInside) {
      _showSnack('⚠️ Ya estás dentro del gimnasio', kYellow);
      return;
    }

    await showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: kPanel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
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
                        'ESCANEAR QR DEL GIMNASIO',
                        style: TextStyle(
                          color: kWhite,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: kWhite),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: MobileScanner(
                    onDetect: (capture) {
                      if (capture.barcodes.isEmpty) return;
                      final raw = capture.barcodes.first.rawValue;
                      if (raw == null || raw.isEmpty) return;
                      Navigator.pop(context);
                      _processGymQr(raw);
                    },
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'Apunta al código QR de la entrada del gimnasio',
                  style: TextStyle(color: kMuted, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processGymQr(String raw) async {
    setState(() => _actionLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // Verificar que sea un QR válido del gym
      final validPrefixes = ['SYNTH-GYM-', 'SYNTHETIX-GYM'];
      final isValid = validPrefixes.any((p) => raw.startsWith(p));

      if (!isValid) {
        if (!mounted) return;
        setState(() => _actionLoading = false);
        _showSnack('❌ QR no válido', kRed);
        return;
      }

      // Registrar entrada
      await supabase.from('checkins').insert({
        'member_id': widget.memberId,
        'type': 'ENTRADA',
        'authorized': true,
      });

      // Actualizar member
      final currentAttendance = (_member!['attendance'] as num?)?.toInt() ?? 0;
      await supabase.from('members').update({
        'is_inside': true,
        'attendance': currentAttendance + 1,
        'last_visit': _formatDate(DateTime.now()),
      }).eq('id', widget.memberId);

      await supabase.from('activities').insert({
        'type': 'ENTRADA',
        'name': _member!['name'].toString(),
      });

      if (!mounted) return;
      setState(() {
        _isInside = true;
        _actionLoading = false;
        _member!['attendance'] = currentAttendance + 1;
      });

      _showSnack('✅ Entrada registrada. ¡Buen entrenamiento!', kGreen);
      await _loadCheckins();
    } catch (e) {
      debugPrint('❌ Error checkin: $e');
      if (!mounted) return;
      setState(() => _actionLoading = false);
      _showSnack('Error al registrar entrada: $e', kRed);
    }
  }

  Future<void> _markExit() async {
    if (!_isInside) {
      _showSnack('⚠️ No estás dentro del gimnasio', kYellow);
      return;
    }

    setState(() => _actionLoading = true);

    try {
      final supabase = Supabase.instance.client;

      await supabase.from('checkins').insert({
        'member_id': widget.memberId,
        'type': 'SALIDA',
        'authorized': true,
      });

      await supabase.from('members').update({
        'is_inside': false,
      }).eq('id', widget.memberId);

      await supabase.from('activities').insert({
        'type': 'SALIDA',
        'name': _member!['name'].toString(),
      });

      if (!mounted) return;
      setState(() {
        _isInside = false;
        _actionLoading = false;
      });

      _showSnack('👋 Salida registrada. ¡Hasta pronto!', kGreen);
      await _loadCheckins();
    } catch (e) {
      debugPrint('❌ Error exit: $e');
      if (!mounted) return;
      setState(() => _actionLoading = false);
      _showSnack('Error al registrar salida: $e', kRed);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('client_id');
    await prefs.remove('client_cedula');
    await prefs.remove('client_name');

    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: kBg,
        body: Center(
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: kPanel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: kBorder),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: kGreen),
                SizedBox(height: 18),
                Text(
                  'Preparando tu perfil',
                  style: TextStyle(
                      color: kWhite, fontSize: 16, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 6),
                Text(
                  'Estamos organizando la información de tu cuenta.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_member == null) {
      return Scaffold(
        backgroundColor: kBg,
        body: Center(
          child: Container(
            width: 420,
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: kPanel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: kBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_search_outlined,
                    color: kMuted, size: 38),
                const SizedBox(height: 14),
                const Text(
                  'No encontramos tu perfil',
                  style: TextStyle(
                      color: kWhite, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Verifica tu conexión e intenta cargar la información nuevamente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kMuted, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _loadAll,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Intentar de nuevo'),
                  style: FilledButton.styleFrom(
                    backgroundColor: kGreen,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final name = _member!['name'].toString();
    final initial = _initials(name);
    final normalizedStatus = status.toUpperCase();
    final isPending =
        normalizedStatus == 'PENDIENTE PAGO' || normalizedStatus == 'PENDIENTE';

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: RefreshIndicator(
          color: kGreen,
          backgroundColor: kPanel,
          onRefresh: _loadAll,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final contentWidth =
                    constraints.maxWidth.clamp(0.0, 1440.0).toDouble();
                final cardColumns = contentWidth >= 1260
                    ? 3
                    : contentWidth >= 660
                        ? 2
                        : 1;
                const cardGap = 20.0;
                final cardWidth = cardColumns == 1
                    ? contentWidth
                    : (contentWidth - (cardColumns - 1) * cardGap) /
                        cardColumns;
                final metricColumns = contentWidth >= 1120
                    ? 4
                    : contentWidth >= 580
                        ? 2
                        : 1;
                final metricWidth = metricColumns == 1
                    ? contentWidth
                    : (contentWidth - (metricColumns - 1) * 12) / metricColumns;
                return Center(
                  child: SizedBox(
                    width: contentWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'PORTAL DEL CLIENTE',
                                    style: TextStyle(
                                      color: kGreen,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    'Hola, ${name.trim().split(RegExp(r'\s+')).first}',
                                    style: const TextStyle(
                                      color: kWhite,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _loadAll,
                              icon: const Icon(Icons.refresh_rounded,
                                  color: kMuted, size: 21),
                              tooltip: 'Actualizar información',
                            ),
                            IconButton(
                              onPressed: _logout,
                              icon: const Icon(Icons.logout_rounded,
                                  color: kMuted, size: 22),
                              tooltip: 'Cerrar sesión',
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tu espacio personal para consultar tu membresía, entrenamientos y actividad.',
                          style: const TextStyle(color: kMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 18),
                        if (isPending) _pendingBanner(),
                        _profileHeader(name, initial),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: metricWidth,
                              child: _overviewMetric(
                                'Visitas registradas',
                                '${_member!['attendance']}',
                                Icons.event_available_rounded,
                              ),
                            ),
                            SizedBox(
                              width: metricWidth,
                              child: _overviewMetric(
                                'Visitas últimos 30 días',
                                '$_visitsLast30Days',
                                Icons.calendar_view_month_rounded,
                              ),
                            ),
                            SizedBox(
                              width: metricWidth,
                              child: _overviewMetric(
                                'Total abonado',
                                '\$${(_member!['totalPaid'] as num).toStringAsFixed(2)}',
                                Icons.account_balance_wallet_outlined,
                              ),
                            ),
                            SizedBox(
                              width: metricWidth,
                              child: _overviewMetric(
                                'Pagos registrados',
                                '${_member!['payments']}',
                                Icons.receipt_long_outlined,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _sectionHeading('Membresía y acceso'),
                        Wrap(
                          spacing: 20,
                          runSpacing: 20,
                          children: [
                            SizedBox(
                                width: cardWidth, child: _membershipCard()),
                            SizedBox(width: cardWidth, child: _accessCard()),
                            SizedBox(width: cardWidth, child: _qrCard()),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _sectionHeading('Entrenamiento y actividad'),
                        Wrap(
                          spacing: 20,
                          runSpacing: 20,
                          children: [
                            SizedBox(width: cardWidth, child: _routineCard()),
                            SizedBox(width: cardWidth, child: _scheduleCard()),
                            SizedBox(width: cardWidth, child: _paymentsCard()),
                            SizedBox(
                                width: cardWidth, child: _attendanceCard()),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeading(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: kWhite,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _pendingBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kPanel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top_rounded, color: kYellow, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Membresía pendiente de activación',
                  style: TextStyle(
                    color: kYellow,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tu pago será confirmado por el administrador. Mientras tanto, puedes ver tu código QR y tus horarios.',
                  style: TextStyle(
                    color: kWhite,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileHeader(String name, String initial) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kPanel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: kPanel2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                  color: kGreen, fontSize: 26, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: kWhite,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    _statusBadge(status, _statusColor),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Plan ${_member!['plan']}',
                  style: const TextStyle(
                      color: kGreen, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 20,
                  runSpacing: 10,
                  children: [
                    _profileDetail(
                        Icons.badge_outlined, 'Cédula', _member!['cedula']),
                    _profileDetail(
                        Icons.phone_outlined, 'Teléfono', _member!['phone']),
                    _profileDetail(
                      Icons.calendar_month_outlined,
                      'Miembro desde',
                      _member!['memberSince'],
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

  Widget _overviewMetric(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kPanel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: kGreen, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: kMuted, fontSize: 11)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        color: kWhite,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileDetail(IconData icon, String label, Object? value) {
    final text = value?.toString().trim() ?? '';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: kMuted, size: 15),
        const SizedBox(width: 6),
        Flexible(
          child: Text('$label: ${text.isEmpty ? 'No registrado' : text}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: kMuted, fontSize: 11)),
        ),
      ],
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: kPanel2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  Widget _membershipCard() {
    final expiry = _parseProfileDate(_member!['expiry']);
    final start = _parseProfileDate(_member!['memberSince']);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysRemaining = expiry?.difference(today).inDays;
    final totalDays =
        expiry != null && start != null ? expiry.difference(start).inDays : 0;
    final elapsedDays = start == null ? 0 : today.difference(start).inDays;
    final progress = totalDays > 0
        ? (elapsedDays / totalDays).clamp(0.0, 1.0).toDouble()
        : null;

    return _card(
      title: 'MI MEMBRESÍA',
      icon: Icons.card_membership_rounded,
      color: _statusColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _member!['plan'].toString(),
                      style: const TextStyle(
                        color: kWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Membresía ${status.toLowerCase()}',
                      style: const TextStyle(color: kMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              _statusBadge(status, _statusColor),
            ],
          ),
          const SizedBox(height: 18),
          _infoRow(
            'Vigencia hasta',
            _member!['expiry'].toString().isEmpty
                ? 'Sin fecha registrada'
                : _member!['expiry'].toString(),
          ),
          _infoRow(
            'Antigüedad',
            _member!['memberSince'].toString().isEmpty
                ? 'Sin registro'
                : _member!['memberSince'].toString(),
          ),
          _infoRow(
            'Última visita',
            _member!['lastVisit'].toString().isEmpty
                ? 'Sin registro'
                : _member!['lastVisit'].toString(),
            isLast: daysRemaining == null,
          ),
          if (daysRemaining != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  daysRemaining < 0
                      ? Icons.error_outline_rounded
                      : daysRemaining <= 7
                          ? Icons.schedule_rounded
                          : Icons.verified_outlined,
                  color: daysRemaining < 0
                      ? kRed
                      : daysRemaining <= 7
                          ? kYellow
                          : kGreen,
                  size: 17,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    daysRemaining < 0
                        ? 'La vigencia terminó hace ${daysRemaining.abs()} días'
                        : daysRemaining == 0
                            ? 'La membresía vence hoy'
                            : 'Quedan $daysRemaining días de vigencia',
                    style: TextStyle(
                      color: daysRemaining < 0
                          ? kRed
                          : daysRemaining <= 7
                              ? kYellow
                              : kMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (progress != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: kPanel2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  daysRemaining != null && daysRemaining <= 7
                      ? kYellow
                      : kGreen,
                ),
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Periodo de membresía transcurrido',
              style: TextStyle(color: kMuted, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  Widget _accessCard() {
    return _card(
      title: 'ACCESO AL GIMNASIO',
      icon: Icons.qr_code_scanner_rounded,
      color: kGreen,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _isInside ? kGreen.withValues(alpha: .10) : kPanel2,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: _isInside ? kGreen.withValues(alpha: .35) : kBorder,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _isInside
                        ? kGreen.withValues(alpha: .18)
                        : kMuted.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isInside
                        ? Icons.check_circle_rounded
                        : Icons.exit_to_app_rounded,
                    color: _isInside ? kGreen : kMuted,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isInside
                            ? 'DENTRO DEL GIMNASIO'
                            : 'FUERA DEL GIMNASIO',
                        style: TextStyle(
                          color: _isInside ? kGreen : kWhite,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isInside
                            ? 'No olvides marcar tu salida'
                            : 'Escanea el código QR del gimnasio para entrar',
                        style: const TextStyle(
                          color: kMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_actionLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(color: kGreen),
            )
          else if (!_isInside)
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _canEnterGym ? _scanGymQr : null,
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                label: Text(
                  _canEnterGym
                      ? 'ESCANEAR QR DEL GIMNASIO'
                      : 'MEMBRESÍA NO ACTIVA',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canEnterGym ? kGreen : kMuted,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: kMuted.withValues(alpha: .30),
                  disabledForegroundColor: kMuted,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _markExit,
                icon: const Icon(Icons.exit_to_app_rounded, size: 20),
                label: const Text(
                  'MARCAR SALIDA',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _qrCard() {
    final qrCode = _member!['qrCode'].toString().trim();
    return _card(
      title: 'MI CÓDIGO DE ACCESO',
      icon: Icons.qr_code_2_rounded,
      color: kGreen,
      child: Column(
        children: [
          if (qrCode.isEmpty)
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: kPanel2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kBorder),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_2_rounded, color: kMuted, size: 42),
                  SizedBox(height: 8),
                  Text('Código no disponible',
                      style: TextStyle(color: kMuted, fontSize: 12)),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: QrImageView(
                data: qrCode,
                size: 188,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
          const SizedBox(height: 14),
          if (qrCode.isNotEmpty)
            SelectableText(
              qrCode,
              style: const TextStyle(
                color: kMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: .5,
              ),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 6),
          const Text(
            'Presenta este código en recepción para identificar tu cuenta.',
            style: TextStyle(color: kMuted, fontSize: 11, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _routineCard() {
    final routine = _member!['assignedRoutine'].toString().trim();
    return _card(
      title: 'MI RUTINA',
      icon: Icons.fitness_center_rounded,
      color: kGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (routine.isEmpty)
            const Text(
              'Aún no tienes una rutina asignada. Consulta con tu entrenador para definir tu plan de entrenamiento.',
              style: TextStyle(color: kMuted, fontSize: 12, height: 1.5),
            )
          else ...[
            Text(
              routine,
              style: const TextStyle(
                color: kWhite,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Rutina asignada por tu gimnasio.',
              style: TextStyle(color: kMuted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, color: kGreen, size: 17),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _classes.isEmpty
                      ? 'Sin clases semanales programadas'
                      : '${_classes.length} ${_classes.length == 1 ? 'clase semanal' : 'clases semanales'} disponibles',
                  style: const TextStyle(color: kMuted, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scheduleCard() {
    if (_classes.isEmpty) {
      return _card(
        title: 'HORARIOS',
        icon: Icons.calendar_today_rounded,
        color: kGreen,
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text(
              'No hay clases programadas',
              style: TextStyle(color: kMuted, fontSize: 12),
            ),
          ),
        ),
      );
    }

    final days = [
      'LUNES',
      'MARTES',
      'MIÉRCOLES',
      'JUEVES',
      'VIERNES',
      'SÁBADO',
      'DOMINGO',
    ];

    return _card(
      title: 'HORARIOS DE ENTRENAMIENTO',
      icon: Icons.calendar_today_rounded,
      color: kGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: days.map((day) {
          final dayClasses = _classes.where((c) => c['day'] == day).toList();
          if (dayClasses.isEmpty) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: kGreen.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    day,
                    style: const TextStyle(
                      color: kGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...dayClasses.map((c) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kPanel2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: kGreen.withValues(alpha: .15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            c['time'].toString(),
                            style: const TextStyle(
                              color: kGreen,
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
                                c['name'].toString(),
                                style: const TextStyle(
                                  color: kWhite,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                [
                                  if (c['type'].toString().trim().isNotEmpty)
                                    _classTypeLabel(c['type']),
                                  if (c['trainer'].toString().trim().isNotEmpty)
                                    'Entrena ${c['trainer']}',
                                ].join(' · '),
                                style: const TextStyle(
                                    color: kMuted, fontSize: 10),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _paymentsCard() {
    return _card(
      title: 'MIS PAGOS',
      icon: Icons.receipt_long_rounded,
      color: kGreen,
      child: _payments.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Sin pagos registrados',
                  style: TextStyle(color: kMuted, fontSize: 12),
                ),
              ),
            )
          : Column(
              children: _payments.map((p) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kPanel2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: kGreen.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.payments_rounded,
                          color: kGreen,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _paymentMethodLabel(p['method']),
                              style: const TextStyle(
                                color: kWhite,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              p['date'].toString(),
                              style: const TextStyle(
                                color: kMuted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '\$${(p['amount'] as num).toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: kGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _attendanceCard() {
    return _card(
      title: 'MI ASISTENCIA',
      icon: Icons.event_available_rounded,
      color: kGreen,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kGreen.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kGreen.withValues(alpha: .30)),
            ),
            child: Row(
              children: [
                const Icon(Icons.emoji_events_rounded, color: kGreen, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Total de visitas: ${_member!['attendance']}',
                    style: const TextStyle(
                      color: kWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_checkins.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Sin registros de entrada/salida',
                style: TextStyle(color: kMuted, fontSize: 12),
              ),
            )
          else
            ..._checkins.take(10).map((c) {
              final isEntrada = c['type'] == 'ENTRADA';
              final color = isEntrada ? kGreen : kMuted;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kPanel2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      isEntrada ? Icons.login_rounded : Icons.logout_rounded,
                      color: color,
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        c['type'].toString(),
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      c['date'].toString(),
                      style: const TextStyle(
                        color: kMuted,
                        fontSize: 10,
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

  Widget _card({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: kWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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

  Widget _infoRow(String label, String value,
      {Color? color, bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(color: kMuted, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: color ?? kWhite,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ═══════════════════════════════════════════════════════════
// COLORES
// ═══════════════════════════════════════════════════════════

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
          .order('created_at', ascending: false)
          .limit(30);

      final loaded = <Map<String, dynamic>>[];
      for (final row in response) {
        final createdAt = DateTime.tryParse(
              row['created_at'].toString(),
            ) ??
            DateTime.now();
        loaded.add({
          'type': row['type'] ?? 'ENTRADA',
          'date': _formatDateTime(createdAt),
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
        '⛔ Tu membresía no está activa. Contacta al admin.',
        kRed,
      );
      return;
    }

    if (_isInside) {
      _showSnack('⚠️ Ya estás dentro del gym', kYellow);
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
                        'ESCANEAR QR DEL GYM',
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
                  'Apunta al QR pegado en la entrada del gym',
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
      _showSnack('⚠️ No estás dentro del gym', kYellow);
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
      return const Scaffold(
        backgroundColor: kBg,
        body: Center(child: CircularProgressIndicator(color: kGreen)),
      );
    }

    if (_member == null) {
      return Scaffold(
        backgroundColor: kBg,
        body: const Center(
          child: Text(
            'No se encontró tu perfil',
            style: TextStyle(color: kMuted),
          ),
        ),
      );
    }

    final name = _member!['name'].toString();
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    final isPending = status.toUpperCase() == 'PENDIENTE PAGO';

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: RefreshIndicator(
          color: kGreen,
          backgroundColor: kPanel,
          onRefresh: _loadAll,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Hola, ${name.split(' ').first}',
                        style: const TextStyle(
                          color: kWhite,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
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
                  'Cédula: ${_member!['cedula']}',
                  style: const TextStyle(color: kMuted, fontSize: 12),
                ),

                const SizedBox(height: 20),

                // Banner pendiente de pago
                if (isPending) _pendingBanner(),

                // Card de perfil
                _profileHeader(name, initial),

                const SizedBox(height: 16),

                // Card de membresía
                _membershipCard(),

                const SizedBox(height: 16),

                // Card de entrada/salida
                _accessCard(),

                const SizedBox(height: 16),

                // Card del QR personal
                _qrCard(),

                const SizedBox(height: 16),

                // Horarios
                _scheduleCard(),

                const SizedBox(height: 16),

                // Historial de pagos
                _paymentsCard(),

                const SizedBox(height: 16),

                // Historial de asistencia
                _attendanceCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pendingBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kYellow.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kYellow.withValues(alpha: .40)),
      ),
      child: const Row(
        children: [
          Icon(Icons.hourglass_top_rounded, color: kYellow, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⏳ Esperando activación',
                  style: TextStyle(
                    color: kYellow,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Tu pago será confirmado por el admin. Mientras tanto, puedes ver tu QR y horarios.',
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _statusColor.withValues(alpha: .15),
            kPanel,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _statusColor.withValues(alpha: .30)),
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_statusColor, _statusColor.withValues(alpha: .6)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _statusColor.withValues(alpha: .30),
                  blurRadius: 20,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.black,
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
                  name,
                  style: const TextStyle(
                    color: kWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Plan ${_member!['plan']}',
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _statusColor.withValues(alpha: .45),
                    ),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: _statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _membershipCard() {
    return _card(
      title: 'MI MEMBRESÍA',
      icon: Icons.card_membership_rounded,
      color: _statusColor,
      child: Column(
        children: [
          _infoRow('Estado', status, color: _statusColor),
          _infoRow('Vence', _member!['expiry'].toString()),
          _infoRow('Miembro desde', _member!['memberSince'].toString()),
          _infoRow('Última visita', _member!['lastVisit'].toString(),
              isLast: true),
        ],
      ),
    );
  }

  Widget _accessCard() {
    return _card(
      title: 'ACCESO AL GYM',
      icon: Icons.qr_code_scanner_rounded,
      color: _isInside ? kGreen : kPurple,
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
                        _isInside ? 'DENTRO DEL GYM' : 'FUERA DEL GYM',
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
                            : 'Escanea el QR del gym para entrar',
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
                  _canEnterGym ? 'ESCANEAR QR DEL GYM' : 'MEMBRESÍA NO ACTIVA',
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
                  backgroundColor: kYellow,
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
    return _card(
      title: 'MI QR PERSONAL',
      icon: Icons.qr_code_2_rounded,
      color: kPurple,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: QrImageView(
              data: _member!['qrCode'].toString(),
              size: 200,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _member!['qrCode'].toString(),
            style: const TextStyle(
              color: kMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Muestra este QR al recepcionista si lo solicita',
            style: TextStyle(color: kMuted, fontSize: 10),
            textAlign: TextAlign.center,
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

    final days = ['LUNES', 'MARTES', 'MIÉRCOLES', 'JUEVES', 'VIERNES'];

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
                            color: kPurple.withValues(alpha: .15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            c['time'].toString(),
                            style: const TextStyle(
                              color: kPurple,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            c['name'].toString(),
                            style: const TextStyle(
                              color: kWhite,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          c['trainer'].toString(),
                          style: const TextStyle(
                            color: kMuted,
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
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
      color: kYellow,
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
                          color: kYellow.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.payments_rounded,
                          color: kYellow,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p['method'].toString(),
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
      color: kPurple,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kPurple.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kPurple.withValues(alpha: .30)),
            ),
            child: Row(
              children: [
                const Icon(Icons.emoji_events_rounded,
                    color: kPurple, size: 22),
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
              final color = isEntrada ? kGreen : kYellow;
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
        borderRadius: BorderRadius.circular(20),
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
              Text(
                title,
                style: const TextStyle(
                  color: kWhite,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
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

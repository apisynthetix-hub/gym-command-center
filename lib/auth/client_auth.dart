import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../client/client_profile.dart';

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
// PANTALLA PRINCIPAL DE AUTENTICACIÓN CLIENTE
// ═══════════════════════════════════════════════════════════

class ClientAuthScreen extends StatelessWidget {
  const ClientAuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: kWhite, size: 20),
        ),
        title: const Text(
          'MIEMBROS',
          style: TextStyle(
            color: kWhite,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: kGreen,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: kGreen.withValues(alpha: .35),
                          blurRadius: 30,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.black,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'ÁREA DE MIEMBROS',
                    style: TextStyle(
                      color: kWhite,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ingresa o crea tu cuenta para acceder',
                    style: TextStyle(color: kMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 40),
                  _authButton(
                    icon: Icons.login_rounded,
                    title: 'YA SOY MIEMBRO',
                    subtitle: 'Ingresa con tu cédula',
                    color: kGreen,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ClientLoginScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _authButton(
                    icon: Icons.person_add_alt_1_rounded,
                    title: 'SOY NUEVO',
                    subtitle: 'Crea tu cuenta en 1 minuto',
                    color: kPurple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ClientRegisterScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'Tu QR personal se genera automáticamente al registrarte',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _authButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: kPanel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withValues(alpha: .35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: .08),
                blurRadius: 20,
                offset: const Offset(0, 6),
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
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: color.withValues(alpha: .40)),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: kWhite,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(color: kMuted, fontSize: 11),
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
}

// ═══════════════════════════════════════════════════════════
// REGISTRO DEL CLIENTE
// ═══════════════════════════════════════════════════════════

class ClientRegisterScreen extends StatefulWidget {
  const ClientRegisterScreen({super.key});

  @override
  State<ClientRegisterScreen> createState() => _ClientRegisterScreenState();
}

class _ClientRegisterScreenState extends State<ClientRegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _cedulaCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String? _selectedPlan;
  bool _loading = false;
  bool _plansLoading = true;
  List<Map<String, dynamic>> _plans = [];

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cedulaCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    try {
      final supabase = Supabase.instance.client;
      final response =
          await supabase.from('plans').select().order('price', ascending: true);

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
        _plans = loaded;
        _plansLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error cargando planes: $e');
      if (!mounted) return;
      setState(() => _plansLoading = false);
    }
  }

  Future<void> _register() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _showError('Ingresa tu nombre completo');
      return;
    }
    if (_cedulaCtrl.text.trim().isEmpty) {
      _showError('Ingresa tu cédula');
      return;
    }
    if (_selectedPlan == null) {
      _showError('Selecciona un plan');
      return;
    }

    setState(() => _loading = true);

    try {
      final supabase = Supabase.instance.client;
      final cedula = _cedulaCtrl.text.trim();

      // Verificar si ya existe
      final existing = await supabase
          .from('members')
          .select('id, name')
          .eq('cedula', cedula)
          .maybeSingle();

      if (existing != null) {
        if (!mounted) return;
        setState(() => _loading = false);
        _showError('Ya existe una cuenta con esta cédula. Inicia sesión.');
        return;
      }

      // Encontrar plan seleccionado
      final plan = _plans.firstWhere(
        (p) => p['name'] == _selectedPlan,
        orElse: () => {},
      );

      if (plan.isEmpty) {
        if (!mounted) return;
        setState(() => _loading = false);
        _showError('Plan no válido');
        return;
      }

      final now = DateTime.now();
      final days = (plan['days'] as num).toInt();
      final expiryDate = now.add(Duration(days: days));
      final qrCode = 'SYNTH-CLIENT-$cedula-${now.millisecondsSinceEpoch}';

      // Insertar en Supabase
      final inserted = await supabase
          .from('members')
          .insert({
            'name': _nameCtrl.text.trim(),
            'cedula': cedula,
            'phone': _phoneCtrl.text.trim().isEmpty
                ? '+00 000 000000'
                : _phoneCtrl.text.trim(),
            'plan': _selectedPlan,
            'expiry': _formatDate(expiryDate),
            'status': 'PENDIENTE PAGO',
            'member_since': _formatDate(now),
            'payments': 0,
            'total_paid': 0,
            'attendance': 0,
            'last_visit': 'Sin registro',
            'qr_code': qrCode,
          })
          .select()
          .single();

      // Registrar actividad
      await supabase.from('activities').insert({
        'type': 'REGISTRO',
        'name': _nameCtrl.text.trim(),
      });

      // Guardar sesión local
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('client_id', inserted['id'].toString());
      await prefs.setString('client_cedula', cedula);
      await prefs.setString('client_name', _nameCtrl.text.trim());

      if (!mounted) return;

      // Navegar al perfil
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ClientProfileScreen(
            memberId: inserted['id'].toString(),
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error registro: $e');
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Error al crear la cuenta: $e');
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

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: kRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: kWhite, size: 20),
        ),
        title: const Text(
          'CREAR CUENTA',
          style: TextStyle(
            color: kWhite,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Únete al gym',
                  style: TextStyle(
                    color: kWhite,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Completa tus datos para crear tu cuenta',
                  style: TextStyle(color: kMuted, fontSize: 13),
                ),
                const SizedBox(height: 28),
                _label('NOMBRE COMPLETO'),
                _input(
                  _nameCtrl,
                  'Ej: Juan Pérez',
                  Icons.person_rounded,
                ),
                const SizedBox(height: 18),
                _label('CÉDULA'),
                _input(
                  _cedulaCtrl,
                  'Ej: V-12345678',
                  Icons.badge_rounded,
                  keyboard: TextInputType.text,
                ),
                const SizedBox(height: 18),
                _label('TELÉFONO (OPCIONAL)'),
                _input(
                  _phoneCtrl,
                  'Ej: +58 412 1234567',
                  Icons.phone_rounded,
                  keyboard: TextInputType.phone,
                ),
                const SizedBox(height: 26),
                _label('ESCOGE TU PLAN'),
                const SizedBox(height: 12),
                if (_plansLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(color: kGreen),
                    ),
                  )
                else if (_plans.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: kPanel,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kBorder),
                    ),
                    child: const Center(
                      child: Text(
                        'No hay planes disponibles.\nContacta al administrador.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: kMuted, fontSize: 12),
                      ),
                    ),
                  )
                else
                  ..._plans.map((p) => _planOption(p)),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGreen,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'CREAR MI CUENTA',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: kYellow.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: kYellow.withValues(alpha: .30)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: kYellow, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tu cuenta quedará PENDIENTE hasta que el admin confirme tu pago.',
                          style: TextStyle(
                            color: kWhite,
                            fontSize: 11,
                            height: 1.4,
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
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: kMuted,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      style: const TextStyle(color: kWhite, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: kMuted, fontSize: 13),
        prefixIcon: Icon(icon, color: kMuted, size: 20),
        filled: true,
        fillColor: kPanel,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kGreen, width: 1.5),
        ),
      ),
    );
  }

  Widget _planOption(Map<String, dynamic> plan) {
    final selected = _selectedPlan == plan['name'];
    final price = (plan['price'] as num).toDouble();
    final days = (plan['days'] as num).toInt();

    Color planColor = kPurple;
    final name = plan['name'].toString().toLowerCase();
    if (name.contains('basic')) planColor = kYellow;
    if (name.contains('premium')) planColor = kRed;
    if (name.contains('elite')) planColor = kPurple;
    if (name.contains('10')) planColor = kGreen;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedPlan = plan['name']),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected ? planColor.withValues(alpha: .12) : kPanel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? planColor.withValues(alpha: .55) : kBorder,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: planColor.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: planColor.withValues(alpha: .35)),
                  ),
                  child: Icon(
                    Icons.card_membership_rounded,
                    color: planColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan['name'].toString().toUpperCase(),
                        style: const TextStyle(
                          color: kWhite,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$days días · ${plan['access']}',
                        style: const TextStyle(
                          color: kMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '\$${price.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: planColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? planColor : kBorder,
                      width: 2,
                    ),
                    color: selected ? planColor : Colors.transparent,
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.black,
                          size: 16,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// LOGIN DEL CLIENTE
// ═══════════════════════════════════════════════════════════

class ClientLoginScreen extends StatefulWidget {
  const ClientLoginScreen({super.key});

  @override
  State<ClientLoginScreen> createState() => _ClientLoginScreenState();
}

class _ClientLoginScreenState extends State<ClientLoginScreen> {
  final _cedulaCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _cedulaCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_cedulaCtrl.text.trim().isEmpty) {
      _showError('Ingresa tu cédula');
      return;
    }

    setState(() => _loading = true);

    try {
      final supabase = Supabase.instance.client;
      final cedula = _cedulaCtrl.text.trim();

      final response = await supabase
          .from('members')
          .select()
          .eq('cedula', cedula)
          .maybeSingle();

      if (response == null) {
        if (!mounted) return;
        setState(() => _loading = false);
        _showError('No existe una cuenta con esta cédula');
        return;
      }

      // Guardar sesión local
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('client_id', response['id'].toString());
      await prefs.setString('client_cedula', cedula);
      await prefs.setString('client_name', response['name'].toString());

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ClientProfileScreen(
            memberId: response['id'].toString(),
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error login: $e');
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Error al iniciar sesión: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: kRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: kWhite, size: 20),
        ),
        title: const Text(
          'INICIAR SESIÓN',
          style: TextStyle(
            color: kWhite,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: kGreen,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: kGreen.withValues(alpha: .35),
                          blurRadius: 30,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.login_rounded,
                      color: Colors.black,
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'BIENVENIDO',
                    style: TextStyle(
                      color: kWhite,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ingresa con tu cédula para continuar',
                    style: TextStyle(color: kMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _cedulaCtrl,
                    style: const TextStyle(color: kWhite, fontSize: 16),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'V-12345678',
                      hintStyle: const TextStyle(
                        color: kMuted,
                        fontSize: 16,
                      ),
                      filled: true,
                      fillColor: kPanel,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: kGreen, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreen,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'ENTRAR',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 1.5,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

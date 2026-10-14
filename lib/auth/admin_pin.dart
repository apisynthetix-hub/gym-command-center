import 'dart:convert';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color kBg = Color(0xFF020202);
const Color kPanel = Color(0xFF070707);
const Color kPanel2 = Color(0xFF0D0D0D);
const Color kBorder = Color(0xFF202020);
const Color kRed = Color(0xFFFF1744);
const Color kYellow = Color(0xFFFFEA00);
const Color kGreen = Color(0xFF00FF85);
const Color kWhite = Color(0xFFF4F4F5);
const Color kMuted = Color(0xFF77777F);

class AdminPinScreen extends StatefulWidget {
  final VoidCallback onSuccess;

  const AdminPinScreen({super.key, required this.onSuccess});

  @override
  State<AdminPinScreen> createState() => _AdminPinScreenState();
}

class _AdminPinScreenState extends State<AdminPinScreen> {
  static const String _pinKey = 'admin_pin_hash';
  static const String _pinPlainKey = 'admin_pin_plain';
  static const String _attemptsKey = 'admin_pin_attempts';
  static const String _blockedUntilKey = 'admin_pin_blocked_until';
  static const String _isFirstTimeKey = 'admin_pin_is_first_time';

  String _input = '';
  String? _error;
  int _attempts = 0;
  DateTime? _blockedUntil;
  bool _loading = true;
  bool _showPinOnFirstTime = false;
  String? _firstTimePin;

  @override
  void initState() {
    super.initState();
    _initPin();
  }

  Future<void> _initPin() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstTime = prefs.getBool(_isFirstTimeKey) ?? true;

    if (isFirstTime) {
      final random = math.Random.secure();
      final pin = List.generate(4, (_) => random.nextInt(10)).join();
      final hash = _hashPin(pin);

      await prefs.setString(_pinKey, hash);
      await prefs.setString(_pinPlainKey, pin);
      await prefs.setBool(_isFirstTimeKey, false);
      await prefs.setInt(_attemptsKey, 0);

      if (!mounted) return;
      setState(() {
        _loading = false;
        _showPinOnFirstTime = true;
        _firstTimePin = pin;
      });
      return;
    }

    final attempts = prefs.getInt(_attemptsKey) ?? 0;
    final blockedUntilMs = prefs.getInt(_blockedUntilKey);

    DateTime? blockedUntil;
    if (blockedUntilMs != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch(blockedUntilMs);
      if (dt.isAfter(DateTime.now())) {
        blockedUntil = dt;
      } else {
        await prefs.remove(_blockedUntilKey);
        await prefs.setInt(_attemptsKey, 0);
      }
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _attempts = blockedUntil != null ? 0 : attempts;
      _blockedUntil = blockedUntil;
    });
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _onKeyTap(String value) async {
    if (_blockedUntil != null && _blockedUntil!.isAfter(DateTime.now())) {
      return;
    }

    if (value == 'DEL') {
      if (_input.isNotEmpty) {
        setState(() {
          _input = _input.substring(0, _input.length - 1);
          _error = null;
        });
      }
      return;
    }

    if (_input.length >= 4) return;

    setState(() {
      _input += value;
      _error = null;
    });

    if (_input.length == 4) {
      await Future.delayed(const Duration(milliseconds: 150));
      await _validatePin();
    }
  }

  Future<void> _validatePin() async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_pinKey);

    if (storedHash == null) {
      setState(() {
        _error = 'Error: PIN no configurado';
        _input = '';
      });
      return;
    }

    final inputHash = _hashPin(_input);

    if (inputHash == storedHash) {
      await prefs.setInt(_attemptsKey, 0);
      await prefs.remove(_blockedUntilKey);
      if (!mounted) return;
      widget.onSuccess();
      return;
    }

    final newAttempts = _attempts + 1;

    if (newAttempts >= 3) {
      final blockedUntil = DateTime.now().add(const Duration(minutes: 1));
      await prefs.setInt(_attemptsKey, 0);
      await prefs.setInt(_blockedUntilKey, blockedUntil.millisecondsSinceEpoch);

      if (!mounted) return;
      setState(() {
        _input = '';
        _attempts = 0;
        _blockedUntil = blockedUntil;
        _error = 'Bloqueado por 1 minuto';
      });

      Future.delayed(const Duration(minutes: 1), () {
        if (mounted) {
          setState(() {
            _blockedUntil = null;
            _error = null;
          });
        }
      });
      return;
    }

    await prefs.setInt(_attemptsKey, newAttempts);

    if (!mounted) return;
    setState(() {
      _input = '';
      _attempts = newAttempts;
      _error = 'PIN incorrecto · Intento $newAttempts de 3';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: kBg,
        body: Center(child: CircularProgressIndicator(color: kGreen)),
      );
    }

    if (_showPinOnFirstTime) return _firstTimeView();

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: kWhite,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: kRed.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kRed.withValues(alpha: .35)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_rounded, color: kRed, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'ADMIN',
                          style: TextStyle(
                            color: kRed,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          color: kRed,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: kRed.withValues(alpha: .35),
                              blurRadius: 30,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.bolt_rounded,
                          color: Colors.black,
                          size: 42,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'ACCESO ADMIN',
                        style: TextStyle(
                          color: kWhite,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ingresa tu PIN de 4 dígitos',
                        style: TextStyle(color: kMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (i) {
                          final filled = i < _input.length;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: 52,
                            height: 62,
                            decoration: BoxDecoration(
                              color:
                                  filled ? kRed.withValues(alpha: .15) : kPanel,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: filled
                                    ? kRed.withValues(alpha: .55)
                                    : kBorder,
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: filled
                                ? Container(
                                    width: 14,
                                    height: 14,
                                    decoration: const BoxDecoration(
                                      color: kRed,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                : null,
                          );
                        }),
                      ),
                      const SizedBox(height: 18),
                      if (_error != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: kRed.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: kRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 34),
                      const SizedBox(height: 26),
                      _keypad(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _keypad() {
    final disabled =
        _blockedUntil != null && _blockedUntil!.isAfter(DateTime.now());

    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Column(
        children: [
          for (var row in [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['', '0', 'DEL'],
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: row.map((k) {
                  if (k.isEmpty) return const SizedBox(width: 78, height: 68);
                  return _keyButton(k, disabled);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _keyButton(String value, bool disabled) {
    final isDel = value == 'DEL';
    return Opacity(
      opacity: disabled ? 0.4 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : () => _onKeyTap(value),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 78,
            height: 68,
            decoration: BoxDecoration(
              color: isDel ? kPanel2 : kPanel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: kBorder),
            ),
            alignment: Alignment.center,
            child: isDel
                ? const Icon(Icons.backspace_rounded, color: kRed, size: 22)
                : Text(
                    value,
                    style: const TextStyle(
                      color: kWhite,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _firstTimeView() {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: kPanel,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: kBorder),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: kGreen.withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: kGreen.withValues(alpha: .45),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.key_rounded,
                        color: kGreen,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'PIN GENERADO',
                      style: TextStyle(
                        color: kWhite,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Guarda este PIN. Lo necesitarás cada vez que entres como admin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: kMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 26,
                        vertical: 22,
                      ),
                      decoration: BoxDecoration(
                        color: kBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: kGreen.withValues(alpha: .45),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        _firstTimePin ?? '----',
                        style: const TextStyle(
                          color: kGreen,
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: kRed.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: kRed.withValues(alpha: .30)),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: kRed,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'NO lo compartas con nadie. Puedes cambiarlo luego en Ajustes.',
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
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          widget.onSuccess();
                        },
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: const Text(
                          'YA LO GUARDÉ, ENTRAR',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'admin_pin.dart';
import 'client_auth.dart';
import '../gym_command_center.dart';

const Color kBg = Color(0xFF020202);
const Color kPanel = Color(0xFF070707);
const Color kRed = Color(0xFFFF1744);
const Color kPurple = Color(0xFFB000FF);
const Color kGreen = Color(0xFF00FF85);
const Color kWhite = Color(0xFFF4F4F5);
const Color kMuted = Color(0xFF77777F);

class RoleSelectorScreen extends StatelessWidget {
  const RoleSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
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
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: kRed,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: kRed.withValues(alpha: .40),
                          blurRadius: 40,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.bolt_rounded,
                        color: Colors.black, size: 52),
                  ),
                  const SizedBox(height: 26),
                  const Text(
                    'SYNTHETIX',
                    style: TextStyle(
                      color: kWhite,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'GYM OS PRO',
                    style: TextStyle(
                      color: kMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 60),
                  _btn(
                    icon: Icons.person_rounded,
                    title: 'SOY CLIENTE',
                    subtitle: 'Regístrate o entra a tu perfil',
                    color: kGreen,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ClientAuthScreen()),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _btn(
                    icon: Icons.shield_rounded,
                    title: 'SOY ADMIN',
                    subtitle: 'Acceso con PIN de seguridad',
                    color: kRed,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminPinScreen(
                          onSuccess: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const GymCommandCenter(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 50),
                  const Text(
                    'v1.0 · SYNTHETIX OS',
                    style: TextStyle(
                        color: kMuted, fontSize: 10, letterSpacing: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _btn({
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
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: kPanel,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: color.withValues(alpha: .35),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: .40)),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: kWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: kMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: color, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

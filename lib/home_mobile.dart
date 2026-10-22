import 'package:flutter/material.dart';
import 'dart:math';
import 'theme.dart';

class AdminHomeMobile extends StatefulWidget {
  final int inside;
  final int capacity;
  final double income;
  final int activeMembers;
  final int expiringSoon;
  final int expired;
  final List<Map<String, String>> activities;
  final int notificationCount;
  final String adminName;
  final VoidCallback onScan;
  final VoidCallback onNewPayment;
  final VoidCallback onNewMember;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenMore;
  final VoidCallback onOpenMemberships;
  final VoidCallback onOpenClients;
  final VoidCallback onOpenFinance;

  const AdminHomeMobile({
    super.key,
    required this.inside,
    required this.capacity,
    required this.income,
    required this.activeMembers,
    required this.expiringSoon,
    required this.expired,
    required this.activities,
    required this.notificationCount,
    required this.adminName,
    required this.onScan,
    required this.onNewPayment,
    required this.onNewMember,
    required this.onOpenNotifications,
    required this.onOpenMore,
    required this.onOpenMemberships,
    required this.onOpenClients,
    required this.onOpenFinance,
  });

  @override
  State<AdminHomeMobile> createState() => _AdminHomeMobileState();
}

class _AdminHomeMobileState extends State<AdminHomeMobile>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _heroController;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500));
    _entryController.forward();

    _heroController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _heroController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final occupancy = widget.capacity == 0
        ? 0.0
        : (widget.inside / widget.capacity).clamp(0.0, 1.0);
    final percent = (occupancy * 100).round();

    // AHORA USAMOS LOS COLORES DEL TEMA
    final bgColor = context.colors.bg;
    final cardColor = context.colors.panel;
    final textWhite = context.colors.white;
    final textGrey = context.colors.muted;

    const neonGreen = Color(0xFF00E676);
    const neonBlue = Color(0xFF00B4D8);
    const neonOrange = Color(0xFFFF9F0A);
    const neonPurple = Color(0xFFD500F9);

    return Scaffold(
      backgroundColor: bgColor, // Dinámico
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── HEADER ───
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BIENVENIDO DE NUEVO',
                            style: TextStyle(
                              color: textGrey,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.adminName,
                            style: TextStyle(
                              color: textWhite,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: cardColor, // Dinámico
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: context.colors.border),
                                ),
                                child: IconButton(
                                    onPressed: widget.onOpenNotifications,
                                    icon: Icon(Icons.notifications_none_rounded,
                                        color: textWhite)),
                              ),
                              if (widget.notificationCount > 0)
                                Positioned(
                                  right: 6,
                                  top: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle),
                                    child: Text('${widget.notificationCount}',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: cardColor, // Dinámico
                              shape: BoxShape.circle,
                              border: Border.all(color: context.colors.border),
                            ),
                            alignment: Alignment.center,
                            child: Icon(Icons.person_rounded, color: textWhite),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // ─── TARJETA HERO (Aforo) ───
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                        color: cardColor, // Dinámico
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                            color: neonBlue.withValues(alpha: 0.3), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: neonBlue.withValues(alpha: 0.1),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          )
                        ]),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('AFORO DEL GIMNASIO',
                                  style: TextStyle(
                                    color: textGrey,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  )),
                              const SizedBox(height: 8),
                              Text('${widget.inside} / ${widget.capacity}',
                                  style: TextStyle(
                                    color: textWhite,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                  )),
                              const SizedBox(height: 4),
                              Text('Personas adentro',
                                  style:
                                      TextStyle(color: textGrey, fontSize: 12)),
                              const SizedBox(height: 20),
                              GestureDetector(
                                onTap: widget.onScan,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                  decoration: BoxDecoration(
                                      color: neonBlue,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              neonBlue.withValues(alpha: 0.3),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        )
                                      ]),
                                  child: const Text('ESCANEAR QR',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      )),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Animación del círculo
                        SizedBox(
                          width: 110,
                          height: 110,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 110,
                                height: 110,
                                child: AnimatedBuilder(
                                  animation: _heroController,
                                  builder: (context, child) {
                                    final animValue = 1.0 -
                                        (1.0 - occupancy) *
                                            _heroController.value;
                                    return CircularProgressIndicator(
                                      value: animValue,
                                      strokeWidth: 12,
                                      backgroundColor:
                                          context.colors.border, // Dinámico
                                      valueColor: const AlwaysStoppedAnimation(
                                          neonBlue),
                                      strokeCap: StrokeCap.round,
                                    );
                                  },
                                ),
                              ),
                              Text('$percent%',
                                  style: TextStyle(
                                      color: textWhite,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ─── BENTO GRID (4 Tarjetas con gráficas reales) ───
                  Row(
                    children: [
                      Expanded(
                          child: _buildProCard(
                              'Ingresos',
                              '\$${widget.income.toStringAsFixed(0)}',
                              widget.income.toDouble(),
                              neonGreen,
                              200,
                              widget.onOpenFinance)),
                      const SizedBox(width: 16),
                      Expanded(
                          child: _buildProCard(
                              'Activos',
                              '${widget.activeMembers}',
                              widget.activeMembers.toDouble(),
                              neonBlue,
                              300,
                              widget.onOpenClients)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                          child: _buildProCard(
                              'Por Vencer',
                              '${widget.expiringSoon}',
                              widget.expiringSoon.toDouble(),
                              neonOrange,
                              400,
                              widget.onOpenMemberships)),
                      const SizedBox(width: 16),
                      Expanded(
                          child: _buildProCard(
                              'Vencidos',
                              '${widget.expired}',
                              widget.expired.toDouble(),
                              neonPurple,
                              500,
                              widget.onOpenMemberships)),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // ─── ACCIONES RÁPIDAS ───
                  Text('ACCIONES RÁPIDAS',
                      style: TextStyle(
                        color: textWhite,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      )),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                          child: _actionTab(Icons.fitness_center_rounded,
                              'NUEVO CLIENTE', neonGreen, widget.onNewMember)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _actionTab(Icons.monetization_on_rounded,
                              'REGISTRAR PAGO', neonBlue, widget.onNewPayment)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _actionTab(Icons.qr_code_scanner_rounded,
                              'ESCANEAR QR', neonOrange, widget.onScan)),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // ─── ACTIVIDAD RECIENTE ───
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('ÚLTIMOS ACCESOS',
                          style: TextStyle(
                            color: textWhite,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          )),
                      GestureDetector(
                          onTap: widget.onOpenMore,
                          child: const Text('VER TODO',
                              style: TextStyle(
                                color: neonBlue,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (widget.activities.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: cardColor, // Dinámico
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: context.colors.border),
                      ),
                      child: Center(
                          child: Text('Sin actividad reciente',
                              style: TextStyle(color: textGrey))),
                    )
                  else
                    Column(
                      children: widget.activities.take(3).map((activity) {
                        final isEntry = activity['type'] == 'ENTRADA';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardColor, // Dinámico
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: context.colors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: (isEntry ? neonGreen : neonPurple)
                                        .withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color:
                                            (isEntry ? neonGreen : neonPurple)
                                                .withValues(alpha: 0.3)),
                                  ),
                                  child: Icon(
                                      isEntry
                                          ? Icons.login_rounded
                                          : Icons.logout_rounded,
                                      color: isEntry ? neonGreen : neonPurple,
                                      size: 22),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(activity['name'] ?? 'Cliente',
                                          style: TextStyle(
                                              color: textWhite,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800)),
                                      Text(
                                          isEntry
                                              ? 'Entrada registrada'
                                              : 'Salida registrada',
                                          style: TextStyle(
                                              color: isEntry
                                                  ? neonGreen
                                                  : neonPurple,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                Text(activity['time'] ?? '',
                                    style: TextStyle(
                                        color: textGrey,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),

          // ─── BOTTOM NAV FLOTANTE ───
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: cardColor.withValues(alpha: 0.95), // Dinámico
                borderRadius: BorderRadius.circular(35),
                border: Border.all(color: context.colors.border),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 25,
                      offset: const Offset(0, 10))
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _navItem(Icons.home_rounded, true, () {}),
                  _navItem(
                      Icons.people_alt_rounded, false, widget.onOpenClients),
                  _navItem(Icons.qr_code_scanner_rounded, false, widget.onScan),
                  _navItem(Icons.payments_rounded, false, widget.onOpenFinance),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── TARJETA PRO ───
  Widget _buildProCard(String title, String valueStr, double value,
      Color accentColor, int delay, VoidCallback onTap) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 1200 + delay),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, animValue, _) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - animValue)),
          child: Opacity(
            opacity: animValue,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.all(18),
                height: 160,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accentColor.withValues(alpha: 0.15),
                      context.colors.panel
                    ], // Dinámico
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                        color: accentColor.withValues(alpha: 0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(title,
                            style: TextStyle(
                                color: context.colors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5)),
                        Icon(Icons.arrow_outward_rounded,
                            color: accentColor, size: 16),
                      ],
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 60,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _DataWavePainter(
                          color: accentColor,
                          progress: animValue,
                          dataValue: value,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(valueStr,
                        style: TextStyle(
                            color: context.colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            height: 1) // Dinámico
                        ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── BOTÓN DE ACCIÓN RÁPIDA PRO ───
  Widget _actionTab(
      IconData icon, String title, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        splashColor: color.withValues(alpha: 0.2),
        highlightColor: color.withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          decoration: BoxDecoration(
            color: context.colors.panel, // Dinámico
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.2),
                        blurRadius: 15,
                        spreadRadius: 2,
                      )
                    ]),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: context.colors.white, // Dinámico
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF00B4D8).withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon,
            color: isActive ? const Color(0xFF00B4D8) : context.colors.muted,
            size: 26),
      ),
    );
  }
}

// ─── PAINTER QUE GENERA LA ONDA BASADA EN LOS DATOS REALES ───
class _DataWavePainter extends CustomPainter {
  final Color color;
  final double progress;
  final double dataValue;

  _DataWavePainter(
      {required this.color, required this.progress, required this.dataValue});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final fillPaint = Paint()..style = PaintingStyle.fill;

    final currentWidth = size.width * progress;

    final path = Path();
    final fillPath = Path();
    final stepX = size.width / 6;

    double normalizedValue = dataValue;
    if (normalizedValue > 100) normalizedValue = 100;
    final amplitude = normalizedValue == 0
        ? 0.0
        : (size.height * 0.6) * (normalizedValue / 10);

    final double baseY = size.height * 0.8;
    final List<double> yPoints = [
      baseY,
      baseY - (amplitude * 0.8),
      baseY - (amplitude * 0.3),
      baseY - (amplitude * 1.0),
      baseY - (amplitude * 0.5),
      baseY - (amplitude * 0.7),
      baseY - (amplitude * 0.4),
    ];

    if (normalizedValue == 0) {
      for (int i = 0; i < yPoints.length; i++) {
        yPoints[i] = baseY;
      }
    }

    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, yPoints[0]);
    path.moveTo(0, yPoints[0]);

    for (int i = 1; i < yPoints.length; i++) {
      final x = i * stepX;
      final y = yPoints[i];
      final prevX = (i - 1) * stepX;
      final prevY = yPoints[i - 1];
      final cp1 = Offset(prevX + (x - prevX) / 2, prevY);
      final cp2 = Offset(prevX + (x - prevX) / 2, y);

      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, x, y);
      fillPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, x, y);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    fillPaint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [color.withValues(alpha: 0.4), color.withValues(alpha: 0.0)],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, currentWidth, size.height));

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DataWavePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.dataValue != dataValue;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'theme.dart';

/// Dashboard móvil de SYNTHETIX GYM OS PRO.
/// Mantiene los callbacks y los datos que entrega el dashboard principal.
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
  late final AnimationController _entryController;
  late final AnimationController _heroController;

  static const Color _lime = Color(0xFFD4FF00);
  static const Color _blue = Color(0xFF0A84FF);
  static const Color _orange = Color(0xFFFF9F0A);
  static const Color _red = Color(0xFFFF453A);
  static const Color _green = Color(0xFF30D158);

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final occupancy = widget.capacity <= 0
        ? 0.0
        : (widget.inside / widget.capacity).clamp(0.0, 1.0).toDouble();
    final percent = (occupancy * 100).round();
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        children: [
          // Luz ambiental sutil para dar profundidad sin recargar la interfaz.
          Positioned(
            top: -110,
            right: -95,
            child: IgnorePointer(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _lime.withValues(alpha: 0.075),
                      _lime.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _entryController,
                curve: Curves.easeOut,
              ),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.025),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _entryController,
                  curve: Curves.easeOutCubic,
                )),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 116),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(colors),
                      const SizedBox(height: 25),
                      _buildSectionEyebrow('RESUMEN OPERATIVO'),
                      const SizedBox(height: 11),
                      _buildOccupancyCard(
                        colors: colors,
                        occupancy: occupancy,
                        percent: percent,
                      ),
                      const SizedBox(height: 25),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Indicadores clave',
                            style: TextStyle(
                              color: colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.45,
                            ),
                          ),
                          Text(
                            'EN TIEMPO REAL',
                            style: TextStyle(
                              color: colors.muted,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 13),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final gap = 12.0;
                          final itemWidth = (constraints.maxWidth - gap) / 2;
                          return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              SizedBox(
                                width: itemWidth,
                                child: _buildMetricCard(
                                  title: 'INGRESOS',
                                  value:
                                      '\$${widget.income.toStringAsFixed(0)}',
                                  subtitle: 'Total del periodo',
                                  icon: Icons.account_balance_wallet_rounded,
                                  color: _green,
                                  dataValue: widget.income,
                                  onTap: widget.onOpenFinance,
                                ),
                              ),
                              SizedBox(
                                width: itemWidth,
                                child: _buildMetricCard(
                                  title: 'MIEMBROS ACTIVOS',
                                  value: '${widget.activeMembers}',
                                  subtitle: 'Membresías vigentes',
                                  icon: Icons.groups_rounded,
                                  color: _blue,
                                  dataValue: widget.activeMembers.toDouble(),
                                  onTap: widget.onOpenClients,
                                ),
                              ),
                              SizedBox(
                                width: itemWidth,
                                child: _buildMetricCard(
                                  title: 'POR VENCER',
                                  value: '${widget.expiringSoon}',
                                  subtitle: 'Requieren seguimiento',
                                  icon: Icons.event_available_rounded,
                                  color: _orange,
                                  dataValue: widget.expiringSoon.toDouble(),
                                  onTap: widget.onOpenMemberships,
                                ),
                              ),
                              SizedBox(
                                width: itemWidth,
                                child: _buildMetricCard(
                                  title: 'VENCIDOS',
                                  value: '${widget.expired}',
                                  subtitle: 'Revisar renovaciones',
                                  icon: Icons.warning_amber_rounded,
                                  color: _red,
                                  dataValue: widget.expired.toDouble(),
                                  onTap: widget.onOpenMemberships,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 28),
                      _buildSectionHeading(
                        'Acciones rápidas',
                        'ATAJOS',
                      ),
                      const SizedBox(height: 13),
                      Row(
                        children: [
                          Expanded(
                            child: _buildAction(
                              icon: Icons.person_add_alt_1_rounded,
                              title: 'Nuevo\ncliente',
                              color: _lime,
                              onTap: widget.onNewMember,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildAction(
                              icon: Icons.payments_rounded,
                              title: 'Registrar\npago',
                              color: _blue,
                              onTap: widget.onNewPayment,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildAction(
                              icon: Icons.qr_code_scanner_rounded,
                              title: 'Escanear\nQR',
                              color: _orange,
                              onTap: widget.onScan,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 29),
                      _buildSectionHeading(
                          'Actividad reciente', 'ÚLTIMOS ACCESOS',
                          onTap: widget.onOpenMore),
                      const SizedBox(height: 13),
                      _buildActivityList(colors),
                      const SizedBox(height: 20),
                      _buildFooterNote(colors),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 16,
            right: 16,
            child: SafeArea(
              top: false,
              child: _buildBottomNavigation(colors),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(dynamic colors) {
    final displayName = widget.adminName.trim().isEmpty
        ? 'Administrador'
        : widget.adminName.trim();
    final firstName = displayName.split(RegExp(r'\s+')).first;

    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _lime,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: _lime.withValues(alpha: 0.15),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(Icons.bolt_rounded,
              color: Color(0xFF10110B), size: 29),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SYNTHETIX  /  GYM OS PRO',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Hola, $firstName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: colors.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: colors.border),
          ),
          child: InkWell(
            onTap: widget.onOpenNotifications,
            borderRadius: BorderRadius.circular(15),
            child: SizedBox(
              width: 46,
              height: 46,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.notifications_none_rounded,
                      color: colors.white, size: 23),
                  if (widget.notificationCount > 0)
                    Positioned(
                      top: 7,
                      right: 7,
                      child: Container(
                        constraints:
                            const BoxConstraints(minWidth: 15, minHeight: 15),
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: const BoxDecoration(
                          color: _red,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          widget.notificationCount > 99
                              ? '99+'
                              : '${widget.notificationCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionEyebrow(String text) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(color: _lime, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: context.colors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildOccupancyCard({
    required dynamic colors,
    required double occupancy,
    required int percent,
  }) {
    final isNearCapacity = widget.capacity > 0 && occupancy >= 0.85;
    final accent = isNearCapacity ? _orange : _lime;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.075),
            colors.panel,
            colors.panel,
          ],
          stops: const [0, 0.52, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.055),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 330;
          final gauge = SizedBox(
            width: compact ? 88 : 106,
            height: compact ? 88 : 106,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: AnimatedBuilder(
                    animation: _heroController,
                    builder: (context, child) => CircularProgressIndicator(
                      value: occupancy *
                          Curves.easeOutCubic.transform(
                            _heroController.value,
                          ),
                      strokeWidth: compact ? 8 : 10,
                      strokeCap: StrokeCap.round,
                      backgroundColor: colors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$percent%',
                      style: TextStyle(
                        color: colors.white,
                        fontSize: compact ? 22 : 27,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'AFORO',
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );

          final info = Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PERSONAS DENTRO',
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 7),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${widget.inside}  /  ${widget.capacity}',
                    style: TextStyle(
                      color: colors.white,
                      fontSize: compact ? 27 : 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.1,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  isNearCapacity
                      ? 'Capacidad casi completa'
                      : 'Control de ocupación en vivo',
                  style: TextStyle(
                    color: isNearCapacity ? _orange : colors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Material(
                  color: accent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: widget.onScan,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 11,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.qr_code_scanner_rounded,
                              size: 16, color: Color(0xFF11120A)),
                          const SizedBox(width: 7),
                          const Text(
                            'ESCANEAR QR',
                            style: TextStyle(
                              color: Color(0xFF11120A),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [info, const SizedBox(width: 10), gauge]),
              ],
            );
          }
          return Row(
            children: [info, const SizedBox(width: 12), gauge],
          );
        },
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double dataValue,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    return Material(
      color: colors.panel,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 158,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withValues(alpha: 0.065), colors.panel],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 31,
                    height: 31,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 17),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_outward_rounded,
                      color: colors.muted, size: 15),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.55,
                ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    color: colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.9,
                    height: 1.05,
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 20,
                width: double.infinity,
                child: CustomPaint(
                  painter: _DataWavePainter(
                    color: color,
                    progress: 1,
                    dataValue: dataValue,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeading(String title, String trailing,
      {VoidCallback? onTap}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: context.colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ),
        if (onTap != null)
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    trailing,
                    style: const TextStyle(
                      color: _lime,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded,
                      color: _lime, size: 13),
                ],
              ),
            ),
          )
        else
          Text(
            trailing,
            style: TextStyle(
              color: context.colors.muted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
      ],
    );
  }

  Widget _buildAction({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    return Material(
      color: colors.panel,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 105),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 23),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityList(dynamic colors) {
    if (widget.activities.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
        decoration: BoxDecoration(
          color: colors.panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          children: [
            Icon(Icons.monitor_heart_outlined, color: colors.muted, size: 28),
            const SizedBox(height: 9),
            Text(
              'Todavía no hay actividad reciente',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Los accesos registrados aparecerán aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.muted, fontSize: 10),
            ),
          ],
        ),
      );
    }

    return Column(
      children: widget.activities.take(4).map((activity) {
        final isEntry = activity['type'] == 'ENTRADA';
        final accent = isEntry ? _green : _blue;
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: colors.panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    isEntry ? Icons.login_rounded : Icons.logout_rounded,
                    color: accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity['name'] ?? 'Cliente',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isEntry
                                ? 'Entrada registrada'
                                : 'Salida registrada',
                            style: TextStyle(
                              color: accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  activity['time'] ?? '',
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFooterNote(dynamic colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shield_moon_outlined, color: colors.muted, size: 13),
        const SizedBox(width: 6),
        Text(
          'SYNTHETIX GYM OS PRO  •  COMMAND CENTER',
          style: TextStyle(
            color: colors.muted,
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.65,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigation(dynamic colors) {
    return Container(
      height: 67,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        color: colors.panel.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.grid_view_rounded, true, () {}, 'Inicio'),
          _navItem(
              Icons.groups_rounded, false, widget.onOpenClients, 'Clientes'),
          _navItem(
              Icons.qr_code_scanner_rounded, false, widget.onScan, 'Escáner'),
          _navItem(Icons.account_balance_wallet_rounded, false,
              widget.onOpenFinance, 'Finanzas'),
        ],
      ),
    );
  }

  Widget _navItem(
    IconData icon,
    bool isActive,
    VoidCallback onTap,
    String label,
  ) {
    final colors = context.colors;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color:
                  isActive ? _lime.withValues(alpha: 0.11) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: isActive ? _lime : colors.muted, size: 21),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: isActive ? _lime : colors.muted,
                    fontSize: 8,
                    fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mini gráfica decorativa: usa la métrica recibida y no modifica datos.
class _DataWavePainter extends CustomPainter {
  final Color color;
  final double progress;
  final double dataValue;

  const _DataWavePainter({
    required this.color,
    required this.progress,
    required this.dataValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final fillPaint = Paint()..style = PaintingStyle.fill;
    final currentWidth = size.width * progress.clamp(0.0, 1.0);
    final safeValue = dataValue.isFinite ? dataValue.abs() : 0.0;
    final normalized =
        (math.log(safeValue + 1) / math.log(101)).clamp(0.0, 1.0);
    final amplitude = size.height * (0.12 + normalized * 0.48);
    final baseY = size.height * 0.82;
    final stepX = size.width / 6;
    final points = <Offset>[];
    for (var i = 0; i <= 6; i++) {
      final wave = math.sin(i * 1.47 + normalized * 2.4);
      final rise = (i / 6) * amplitude * 0.28;
      points.add(
          Offset(i * stepX, baseY - amplitude * (0.42 + wave * 0.42) - rise));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final middle = (previous.dx + current.dx) / 2;
      path.cubicTo(
          middle, previous.dy, middle, current.dy, current.dx, current.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    fillPaint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.0)],
    ).createShader(Offset.zero & size);

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

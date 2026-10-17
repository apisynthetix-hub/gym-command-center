// lib/home_mobile.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';

class AdminHomeMobile extends StatefulWidget {
  final int inside;
  final int capacity;
  final double income;
  final int activeMembers;
  final int expiringSoon;
  final int expired;
  final List<Map<String, String>> activities;
  final VoidCallback onScan;
  final VoidCallback onNewPayment;
  final VoidCallback onNewMember;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenMore;
  final VoidCallback onOpenMemberships;
  final VoidCallback onOpenClients;
  final VoidCallback onOpenFinance;
  final int notificationCount;
  final String adminName;

  const AdminHomeMobile({
    super.key,
    required this.inside,
    required this.capacity,
    required this.income,
    required this.activeMembers,
    required this.expiringSoon,
    required this.expired,
    required this.activities,
    required this.onScan,
    required this.onNewPayment,
    required this.onNewMember,
    required this.onOpenNotifications,
    required this.onOpenMore,
    required this.onOpenMemberships,
    required this.onOpenClients,
    required this.onOpenFinance,
    this.notificationCount = 0,
    this.adminName = 'Admin',
  });

  @override
  State<AdminHomeMobile> createState() => _AdminHomeMobileState();
}

class _AdminHomeMobileState extends State<AdminHomeMobile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _gaugeCtrl;
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _gaugeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..forward();
  }

  @override
  void didUpdateWidget(covariant AdminHomeMobile old) {
    super.didUpdateWidget(old);
    if (old.inside != widget.inside || old.capacity != widget.capacity) {
      _gaugeCtrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _gaugeCtrl.dispose();
    super.dispose();
  }

  double get _occ => widget.capacity == 0
      ? 0
      : (widget.inside / widget.capacity).clamp(0.0, 1.0);

  Color _gaugeColor(BuildContext c) {
    if (_occ >= 0.8) return c.colors.red;
    if (_occ >= 0.5) return c.colors.yellow;
    return c.colors.green;
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(context),
                    const SizedBox(height: 24),
                    _aforoCard(context),
                    const SizedBox(height: 24),
                    _sectionLabel(context, 'MÉTRICAS'),
                    const SizedBox(height: 12),
                    _metricsGrid(context),
                    const SizedBox(height: 24),
                    _sectionLabel(context, 'ACCIONES RÁPIDAS'),
                    const SizedBox(height: 12),
                    _quickActions(context),
                    const SizedBox(height: 24),
                    _sectionLabel(context, 'ACTIVIDAD RECIENTE'),
                    const SizedBox(height: 12),
                    _activityList(context),
                  ],
                ),
              ),
            ),
            _bottomNavBar(context),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting,
                  style: TextStyle(
                    color: context.colors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(height: 4),
              Text(widget.adminName,
                  style: TextStyle(
                    color: context.colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  )),
            ],
          ),
        ),
        GestureDetector(
          onTap: widget.onOpenNotifications,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: context.colors.panel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.colors.border),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.notifications_none_rounded,
                    color: context.colors.white, size: 22),
                if (widget.notificationCount > 0)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      decoration: BoxDecoration(
                        color: context.colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        widget.notificationCount > 9
                            ? '9+'
                            : '${widget.notificationCount}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _aforoCard(BuildContext context) {
    final pct = (_occ * 100).round();
    final free = (widget.capacity - widget.inside).clamp(0, widget.capacity);
    final gaugeColor = _gaugeColor(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.colors.panel,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: gaugeColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('AFORO EN VIVO',
                        style: TextStyle(
                          color: gaugeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.8,
                        )),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      child: Text(
                        '${widget.inside}',
                        key: ValueKey(widget.inside),
                        style: TextStyle(
                          color: context.colors.white,
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.5,
                          height: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('/ ${widget.capacity}',
                        style: TextStyle(
                          color: context.colors.muted,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                ),
                const SizedBox(height: 8),
                Text('$free espacios libres',
                    style: TextStyle(
                      color: context.colors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _AnimatedGauge(
            controller: _gaugeCtrl,
            progress: _occ,
            color: gaugeColor,
            percent: pct,
            track: context.colors.border,
            textColor: context.colors.white,
          ),
        ],
      ),
    );
  }

  Widget _metricsGrid(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _InteractiveMetricTile(
                label: 'Ingresos',
                value: _money(widget.income),
                accent: context.colors.green,
                icon: Icons.attach_money_rounded,
                spark: const [0.4, 0.5, 0.45, 0.6, 0.55, 0.7, 0.85, 1.0],
                footer: 'este mes',
                detailTitle: 'Ingresos del mes',
                detailValue: _money(widget.income),
                detailSubtitle: 'Suma total de pagos registrados',
                detailRows: const [
                  ['Hoy', '\$0.00'],
                  ['Esta semana', '\$0.00'],
                  ['Este mes', 'Actual'],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InteractiveMetricTile(
                label: 'Miembros',
                value: '${widget.activeMembers}',
                accent: context.colors.blue,
                icon: Icons.people_alt_rounded,
                spark: const [0.5, 0.55, 0.6, 0.58, 0.7, 0.75, 0.85, 1.0],
                footer: 'activos',
                detailTitle: 'Miembros activos',
                detailValue: '${widget.activeMembers}',
                detailSubtitle: 'Con membresía vigente',
                detailRows: [
                  ['Activos', '${widget.activeMembers}'],
                  ['Por vencer', '${widget.expiringSoon}'],
                  ['Vencidos', '${widget.expired}'],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _InteractiveMetricTile(
                label: 'Por vencer',
                value: '${widget.expiringSoon}',
                accent: context.colors.yellow,
                icon: Icons.schedule_rounded,
                spark: const [0.3, 0.4, 0.35, 0.5, 0.45, 0.55, 0.5, 0.6],
                footer: 'próximos 7 días',
                detailTitle: 'Por vencer',
                detailValue: '${widget.expiringSoon}',
                detailSubtitle: 'Membresías que vencen pronto',
                detailRows: const [
                  ['Próximos 3 días', '0'],
                  ['Próximos 7 días', 'Actual'],
                  ['Próximos 15 días', '0'],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InteractiveMetricTile(
                label: 'Vencidos',
                value: '${widget.expired}',
                accent: context.colors.red,
                icon: Icons.block_rounded,
                spark: const [0.9, 0.8, 0.85, 0.7, 0.65, 0.6, 0.55, 0.5],
                footer: 'requieren renovar',
                detailTitle: 'Vencidos',
                detailValue: '${widget.expired}',
                detailSubtitle: 'Membresías expiradas',
                detailRows: [
                  ['Vencidos hoy', '${widget.expired}'],
                  ['Esta semana', '0'],
                  ['Este mes', '0'],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _quickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.qr_code_scanner_rounded,
            label: 'Escanear',
            color: context.colors.red,
            onTap: widget.onScan,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickAction(
            icon: Icons.payments_rounded,
            label: 'Pago',
            color: context.colors.green,
            onTap: widget.onNewPayment,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickAction(
            icon: Icons.person_add_alt_1_rounded,
            label: 'Miembro',
            color: context.colors.blue,
            onTap: widget.onNewMember,
          ),
        ),
      ],
    );
  }

  Widget _activityList(BuildContext context) {
    if (widget.activities.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: context.colors.panel,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: context.colors.border),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.bolt_rounded, color: context.colors.muted, size: 32),
              const SizedBox(height: 12),
              Text('Sin actividad',
                  style: TextStyle(
                    color: context.colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 4),
              Text('Los eventos aparecerán aquí',
                  style: TextStyle(
                    color: context.colors.muted,
                    fontSize: 11,
                  )),
            ],
          ),
        ),
      );
    }

    final list = widget.activities.take(5).toList();
    return Container(
      decoration: BoxDecoration(
        color: context.colors.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          for (int i = 0; i < list.length; i++)
            _ActivityRow(
              activity: list[i],
              isLast: i == list.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _bottomNavBar(BuildContext context) {
    final items = [
      {'icon': Icons.home_rounded, 'label': 'Inicio'},
      {'icon': Icons.card_membership_rounded, 'label': 'Membresías'},
      {'icon': Icons.people_alt_rounded, 'label': 'Clientes'},
      {'icon': Icons.payments_rounded, 'label': 'Finanzas'},
      {'icon': Icons.more_horiz_rounded, 'label': 'Más'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.colors.panel,
        border: Border(top: BorderSide(color: context.colors.border)),
      ),
      padding: EdgeInsets.only(
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final active = _navIndex == i;
          final isMore = i == 4;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (isMore) {
                  widget.onOpenMore();
                  return;
                }
                setState(() => _navIndex = i);
                switch (i) {
                  case 0:
                    break;
                  case 1:
                    widget.onOpenMemberships();
                    break;
                  case 2:
                    widget.onOpenClients();
                    break;
                  case 3:
                    widget.onOpenFinance();
                    break;
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: active
                          ? context.colors.red.withValues(alpha: .15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      items[i]['icon'] as IconData,
                      color: active ? context.colors.red : context.colors.muted,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    items[i]['label'] as String,
                    style: TextStyle(
                      color: active ? context.colors.red : context.colors.muted,
                      fontSize: 10,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String t) => Text(t,
      style: TextStyle(
        color: context.colors.muted,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.8,
      ));

  String _money(double v) {
    if (v >= 1000000) return '\$${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '\$${(v / 1000).toStringAsFixed(1)}K';
    return '\$${v.toStringAsFixed(2)}';
  }
}

class _InteractiveMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final IconData icon;
  final List<double> spark;
  final String footer;
  final String detailTitle;
  final String detailValue;
  final String detailSubtitle;
  final List<List<String>> detailRows;

  const _InteractiveMetricTile({
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
    required this.spark,
    required this.footer,
    required this.detailTitle,
    required this.detailValue,
    required this.detailSubtitle,
    required this.detailRows,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.panel,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accent, size: 18),
            ),
            const SizedBox(height: 16),
            Text(label,
                style: TextStyle(
                  color: context.colors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                )),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                  color: context.colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                  height: 1.0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            SizedBox(
              height: 32,
              width: double.infinity,
              child: CustomPaint(
                painter: _SparkPainter(data: spark, color: accent),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(footer,
                      style: TextStyle(
                        color: context.colors.muted,
                        fontSize: 10,
                      )),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    color: context.colors.muted, size: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: ctx.colors.panel,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
              24, 16, 24, MediaQuery.of(ctx).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ctx.colors.muted.withValues(alpha: .4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: accent, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(detailTitle,
                            style: TextStyle(
                              color: ctx.colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            )),
                        const SizedBox(height: 2),
                        Text(detailSubtitle,
                            style: TextStyle(
                              color: ctx.colors.muted,
                              fontSize: 11,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(detailValue,
                  style: TextStyle(
                    color: accent,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  )),
              const SizedBox(height: 24),
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: ctx.colors.panel2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ctx.colors.border),
                ),
                padding: const EdgeInsets.all(12),
                child: CustomPaint(
                  painter: _SparkPainter(data: spark, color: accent),
                ),
              ),
              const SizedBox(height: 20),
              ...detailRows.map((row) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(row[0],
                              style: TextStyle(
                                color: ctx.colors.muted,
                                fontSize: 13,
                              )),
                        ),
                        Text(row[1],
                            style: TextStyle(
                              color: ctx.colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            )),
                      ],
                    ),
                  )),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _AnimatedGauge extends StatelessWidget {
  final AnimationController controller;
  final double progress;
  final Color color;
  final int percent;
  final Color track;
  final Color textColor;

  const _AnimatedGauge({
    required this.controller,
    required this.progress,
    required this.color,
    required this.percent,
    required this.track,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      height: 110,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final curved = CurvedAnimation(
            parent: controller,
            curve: Curves.easeOutCubic,
          ).value;
          return CustomPaint(
            painter: _GaugePainter(
              progress: progress * curved,
              color: color,
              trackColor: track,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$percent',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      )),
                  Text('%',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _GaugePainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeW = 8.0;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawArc(rect, -math.pi / 2, sweep, false, glowPaint);

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, progressPaint);

    final endAngle = -math.pi / 2 + sweep;
    final tipX = center.dx + radius * math.cos(endAngle);
    final tipY = center.dy + radius * math.sin(endAngle);
    canvas.drawCircle(
        Offset(tipX, tipY), strokeW / 2 + 1, Paint()..color = color);

    final tipGlow = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(tipX, tipY), strokeW, tipGlow);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.progress != progress || old.color != color;
}

class _SparkPainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _SparkPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final maxV = data.reduce((a, b) => a > b ? a : b);
    final minV = data.reduce((a, b) => a < b ? a : b);
    final range = (maxV - minV) == 0 ? 1.0 : (maxV - minV);
    final stepX = size.width / (data.length - 1);
    final pts = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final n = (data[i] - minV) / range;
      final y = size.height - (n * (size.height - 4)) - 2;
      pts.add(Offset(x, y));
    }

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i];
      final p1 = pts[i + 1];
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
      if (i == pts.length - 2) path.lineTo(p1.dx, p1.dy);
    }

    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.28),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fill, fillPaint);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, stroke);

    final last = pts.last;
    canvas.drawCircle(last, 3, Paint()..color = color);
    canvas.drawCircle(last, 6, Paint()..color = color.withValues(alpha: 0.25));
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.data != data || old.color != color;
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: context.colors.panel,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(
                    color: context.colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final Map<String, String> activity;
  final bool isLast;

  const _ActivityRow({required this.activity, required this.isLast});

  Color _color(BuildContext context) {
    switch (activity['type']) {
      case 'ENTRADA':
        return context.colors.green;
      case 'SALIDA':
        return context.colors.blue;
      case 'PAGO':
        return context.colors.yellow;
      case 'BLOQUEADO':
        return context.colors.red;
      case 'RENOVACIÓN':
        return context.colors.yellow;
      default:
        return context.colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: context.colors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.bolt_rounded, color: c, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity['name'] ?? '',
                    style: TextStyle(
                      color: context.colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(activity['type'] ?? '',
                    style: TextStyle(
                      color: context.colors.muted,
                      fontSize: 10,
                    )),
              ],
            ),
          ),
          Text(activity['time'] ?? '',
              style: TextStyle(
                color: context.colors.muted,
                fontSize: 11,
              )),
        ],
      ),
    );
  }
}

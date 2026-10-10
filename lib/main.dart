import 'gym_command_center.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

void main() {
  runApp(const SynthetixGymApp());
}

class AppColors {
  static const bg = Color(0xFF05070D);
  static const panel = Color(0xFF0C101A);
  static const panel2 = Color(0xFF111725);
  static const border = Color(0xFF20283A);

  static const purple = Color(0xFF8B5CF6);
  static const violet = Color(0xFFA855F7);
  static const blue = Color(0xFF2563EB);
  static const cyan = Color(0xFF06B6D4);

  static const green = Color(0xFF22C55E);
  static const orange = Color(0xFFF59E0B);
  static const red = Color(0xFFEF4444);
  static const pink = Color(0xFFEC4899);

  static const text = Color(0xFFF4F7FF);
  static const muted = Color(0xFF7F899F);
}

class SynthetixGymApp extends StatelessWidget {
  const SynthetixGymApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SYNTHETIX GYM OS PRO',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.purple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const GymCommandCenter(),
    );
  }
}

class GymHome extends StatefulWidget {
  const GymHome({super.key});

  @override
  State<GymHome> createState() => _GymHomeState();
}

class _GymHomeState extends State<GymHome> {
  int current = 0;

  final sections = const [
    'Dashboard',
    'Clientes',
    'Acceso QR',
    'Membresias',
    'Finanzas',
    'Entrenamiento',
    'Analytics',
    'Alertas',
  ];

  final icons = const [
    Icons.dashboard_rounded,
    Icons.groups_rounded,
    Icons.qr_code_scanner_rounded,
    Icons.workspace_premium_rounded,
    Icons.payments_rounded,
    Icons.fitness_center_rounded,
    Icons.insights_rounded,
    Icons.notifications_active_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 900;

        return Scaffold(
          backgroundColor: AppColors.bg,
          body: mobile
              ? _mobile(context)
              : Row(
                  children: [
                    _sidebar(),
                    Expanded(child: _desktop(context)),
                  ],
                ),
          floatingActionButton: mobile
              ? FloatingActionButton.extended(
                  backgroundColor: AppColors.purple,
                  foregroundColor: Colors.white,
                  onPressed: () => _newPayment(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(
                    'NUEVO PAGO',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _sidebar() {
    return Container(
      width: 255,
      decoration: const BoxDecoration(
        color: Color(0xFF080B13),
        border: Border(
          right: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 19),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.violet,
                        AppColors.blue,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x558B5CF6),
                        blurRadius: 22,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 11),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SYNTHETIX',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      'GYM OS PRO',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 35),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'COMMAND CENTER',
                style: TextStyle(
                  color: Color(0xFF566075),
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 11),
              itemCount: sections.length,
              itemBuilder: (context, index) {
                final active = current == index;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      setState(() {
                        current = index;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        gradient: active
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFF392066),
                                  Color(0xFF142B59),
                                ],
                              )
                            : null,
                        borderRadius: BorderRadius.circular(14),
                        border: active
                            ? Border.all(
                                color: const Color(0x405F5AF6),
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            icons[index],
                            size: 20,
                            color:
                                active ? Colors.white : const Color(0xFF778197),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              sections[index],
                              style: TextStyle(
                                color: active
                                    ? Colors.white
                                    : const Color(0xFF929AAF),
                                fontSize: 12,
                                fontWeight:
                                    active ? FontWeight.w800 : FontWeight.w600,
                              ),
                            ),
                          ),
                          if (index == 7)
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: AppColors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.panel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: Color(0xFF252C40),
                  child: Icon(
                    Icons.person_rounded,
                    color: Color(0xFFB6BED2),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Administrador',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'GYM PRINCIPAL',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 8,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.more_horiz_rounded,
                  color: Color(0xFF697287),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktop(BuildContext context) {
    return Column(
      children: [
        _header(context),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              30,
              27,
              30,
              45,
            ),
            child: _dashboard(false),
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(
          bottom: BorderSide(color: Color(0xFF1A2130)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  sections[current],
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 12),
                _onlineBadge(),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search_rounded),
            color: AppColors.muted,
          ),
          IconButton(
            onPressed: () => setState(() => current = 7),
            icon: const Icon(Icons.notifications_none_rounded),
            color: AppColors.muted,
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _newPayment(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'NUEVO PAGO',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.purple,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 15,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _onlineBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0x1516A34A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0x3034D399),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 3,
            backgroundColor: AppColors.green,
          ),
          SizedBox(width: 6),
          Text(
            'ONLINE',
            style: TextStyle(
              color: Color(0xFF6EE7B7),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobile(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 9),
            child: Row(
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.violet,
                        AppColors.blue,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.bolt_rounded),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SYNTHETIX',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        'GYM OS PRO',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 8,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.notifications_none_rounded,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                16,
                5,
                16,
                105,
              ),
              child: _dashboard(true),
            ),
          ),
          _bottomNav(),
        ],
      ),
    );
  }

  Widget _dashboard(bool mobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _hero(mobile),
        const SizedBox(height: 18),
        _quickActions(mobile),
        const SizedBox(height: 18),
        _stats(mobile),
        const SizedBox(height: 18),
        _charts(mobile),
        const SizedBox(height: 18),
        _activity(mobile),
      ],
    );
  }

  Widget _hero(bool mobile) {
    return Container(
      padding: EdgeInsets.all(mobile ? 19 : 25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1B1233),
            Color(0xFF101D37),
            Color(0xFF0D1526),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0x332E4070),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x35000000),
            blurRadius: 32,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: mobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heroText(),
                const SizedBox(height: 22),
                _occupancy(),
              ],
            )
          : Row(
              children: [
                Expanded(
                  flex: 6,
                  child: _heroText(),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 4,
                  child: _occupancy(),
                ),
              ],
            ),
    );
  }

  Widget _heroText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: const Color(0x198B5CF6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0x408B5CF6),
            ),
          ),
          child: const Text(
            'LIVE GYM COMMAND CENTER',
            style: TextStyle(
              color: Color(0xFFC4B5FD),
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Buenos dias, administrador',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Controla el rendimiento de tu gimnasio en tiempo real.',
          style: TextStyle(
            color: Color(0xFF929AAF),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            _mini('486', 'miembros'),
            _mini('18', 'por vencer'),
            _mini('\$18,420', 'ingresos'),
          ],
        ),
      ],
    );
  }

  Widget _mini(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0x15151C2D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0x202E3850),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: .6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _occupancy() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0x18000000),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0x26364761),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: CustomPaint(
              painter: _OccupancyPainter(),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '58%',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'AFORO',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 17),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PERSONAS DENTRO',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  '87',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'de 150 capacidad',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 9,
                  ),
                ),
                SizedBox(height: 11),
                Row(
                  children: [
                    Icon(
                      Icons.trending_up_rounded,
                      color: AppColors.green,
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '+12% hoy',
                      style: TextStyle(
                        color: Color(0xFF6EE7B7),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 9),
                Text(
                  '63 espacios libres',
                  style: TextStyle(
                    color: Color(0xFF8C95A9),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActions(bool mobile) {
    final actions = [
      [Icons.qr_code_scanner_rounded, 'Escanear QR'],
      [Icons.person_add_alt_1_rounded, 'Nuevo cliente'],
      [Icons.workspace_premium_rounded, 'Nueva membresia'],
      [Icons.payments_rounded, 'Registrar pago'],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('ACCIONES RAPIDAS', 'Acceso directo'),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: mobile ? 2 : 4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: mobile ? 1.75 : 2.25,
          ),
          itemBuilder: (context, index) {
            final item = actions[index];

            return InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: () {
                if (index == 0) {
                  setState(() => current = 2);
                } else if (index == 1) {
                  setState(() => current = 1);
                } else if (index == 2) {
                  setState(() => current = 3);
                } else {
                  _newPayment(context);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppColors.panel,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0x198B5CF6),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        item[0] as IconData,
                        color: const Color(0xFFA78BFA),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item[1] as String,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: Color(0xFF596277),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _stats(bool mobile) {
    final data = [
      [
        '\$18,420',
        'INGRESOS DEL MES',
        '+14.2%',
        Icons.payments_rounded,
        AppColors.green,
      ],
      [
        '486',
        'MIEMBROS ACTIVOS',
        '+4.8%',
        Icons.groups_rounded,
        Color(0xFF60A5FA),
      ],
      [
        '18',
        'POR VENCER',
        '7 dias',
        Icons.warning_amber_rounded,
        AppColors.orange,
      ],
      [
        '92%',
        'RETENCION',
        '+3.1%',
        Icons.favorite_rounded,
        AppColors.pink,
      ],
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: data.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: mobile ? 2 : 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: mobile ? 1.38 : 1.75,
      ),
      itemBuilder: (context, index) {
        final item = data[index];

        return _statCard(
          item[0] as String,
          item[1] as String,
          item[2] as String,
          item[3] as IconData,
          item[4] as Color,
        );
      },
    );
  }

  Widget _statCard(
    String value,
    String label,
    String trend,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 19,
                ),
              ),
              const Spacer(),
              Text(
                trend,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: .5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _charts(bool mobile) {
    final revenue = _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _chartTitle(
            'Ingresos',
            'Ultimos 7 dias',
            Icons.show_chart_rounded,
          ),
          const SizedBox(height: 15),
          Expanded(
            child: CustomPaint(
              painter: _RevenuePainter(),
            ),
          ),
        ],
      ),
    );

    final attendance = _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _chartTitle(
            'Asistencia',
            'Entradas por hora',
            Icons.bar_chart_rounded,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: CustomPaint(
              painter: _BarsPainter(),
            ),
          ),
        ],
      ),
    );

    if (mobile) {
      return SizedBox(
        height: 620,
        child: Column(
          children: [
            Expanded(child: revenue),
            const SizedBox(height: 14),
            Expanded(child: attendance),
          ],
        ),
      );
    }

    return SizedBox(
      height: 330,
      child: Row(
        children: [
          Expanded(flex: 3, child: revenue),
          const SizedBox(width: 14),
          Expanded(flex: 2, child: attendance),
        ],
      ),
    );
  }

  Widget _activity(bool mobile) {
    final activity = _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _chartTitle(
            'Actividad en vivo',
            'Ultimos movimientos',
            Icons.bolt_rounded,
          ),
          const SizedBox(height: 10),
          ...[
            ['Carlos Mendoza', 'Entrada registrada', '09:42'],
            ['Maria Lopez', 'Pago recibido', '09:31'],
            ['Ana Torres', 'Renovacion', '09:18'],
            ['Luis Perez', 'Nuevo miembro', '08:56'],
          ].map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFF20283B),
                    child: Icon(
                      Icons.person_rounded,
                      size: 16,
                      color: Color(0xFFB9C2D5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row[0],
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          row[1],
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    row[2],
                    style: const TextStyle(
                      color: Color(0xFF687186),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final alerts = _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _chartTitle(
            'Alertas inteligentes',
            'Requieren atencion',
            Icons.auto_awesome_rounded,
          ),
          const SizedBox(height: 12),
          _alert(
            '18 membresias vencen pronto',
            AppColors.orange,
            Icons.warning_amber_rounded,
          ),
          _alert(
            '6 clientes sin visita',
            AppColors.red,
            Icons.person_off_rounded,
          ),
          _alert(
            'Hora pico: 18:00 - 20:00',
            AppColors.purple,
            Icons.schedule_rounded,
          ),
        ],
      ),
    );

    if (mobile) {
      return Column(
        children: [
          SizedBox(height: 275, child: activity),
          const SizedBox(height: 14),
          SizedBox(height: 235, child: alerts),
        ],
      );
    }

    return SizedBox(
      height: 275,
      child: Row(
        children: [
          Expanded(child: activity),
          const SizedBox(width: 14),
          Expanded(child: alerts),
        ],
      ),
    );
  }

  Widget _alert(
    String text,
    Color color,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: color.withAlpha(35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF596277),
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: AppColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x19000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _chartTitle(
    String title,
    String subtitle,
    IconData icon,
  ) {
    return Row(
      children: [
        Container(
          width: 35,
          height: 35,
          decoration: BoxDecoration(
            color: const Color(0x198B5CF6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: const Color(0xFFA78BFA),
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
        const Icon(
          Icons.more_horiz_rounded,
          color: Color(0xFF5C657A),
          size: 20,
        ),
      ],
    );
  }

  Widget _title(String title, String subtitle) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF80899E),
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          '|',
          style: TextStyle(
            color: Color(0xFF414A5D),
            fontSize: 9,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF5E687D),
            fontSize: 9,
          ),
        ),
      ],
    );
  }

  Widget _bottomNav() {
    final items = [
      [Icons.dashboard_rounded, 'Inicio', 0],
      [Icons.groups_rounded, 'Clientes', 1],
      [Icons.qr_code_scanner_rounded, 'QR', 2],
      [Icons.workspace_premium_rounded, 'Planes', 3],
      [Icons.more_horiz_rounded, 'Mas', 7],
    ];

    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: Color(0xFF080B13),
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map(
          (item) {
            final active = current == item[2];

            return InkWell(
              onTap: () {
                setState(() {
                  current = item[2] as int;
                });
              },
              child: SizedBox(
                width: 58,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item[0] as IconData,
                      size: 21,
                      color: active
                          ? const Color(0xFFA78BFA)
                          : const Color(0xFF727B90),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item[1] as String,
                      style: TextStyle(
                        color: active
                            ? const Color(0xFFA78BFA)
                            : const Color(0xFF727B90),
                        fontSize: 8,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ).toList(),
      ),
    );
  }

  void _newPayment(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.panel2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Nuevo pago',
            style: TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Cliente',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Monto',
                    prefixIcon: Icon(Icons.attach_money_rounded),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Concepto',
                    prefixIcon: Icon(Icons.receipt_long_rounded),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCELAR'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('REGISTRAR'),
            ),
          ],
        );
      },
    );
  }
}

class _OccupancyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 10;

    final background = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF252D40);

    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [
          AppColors.purple,
          AppColors.blue,
          AppColors.green,
        ],
      ).createShader(
        Rect.fromCircle(
          center: center,
          radius: radius,
        ),
      );

    final rect = Rect.fromCircle(
      center: center,
      radius: radius,
    );

    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2,
      false,
      background,
    );

    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * .58,
      false,
      progress,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RevenuePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final points = [
      Offset(0, size.height * .73),
      Offset(size.width * .14, size.height * .58),
      Offset(size.width * .28, size.height * .65),
      Offset(size.width * .42, size.height * .43),
      Offset(size.width * .56, size.height * .52),
      Offset(size.width * .70, size.height * .24),
      Offset(size.width * .85, size.height * .34),
      Offset(size.width, size.height * .12),
    ];

    final linePath = Path()
      ..moveTo(
        points.first.dx,
        points.first.dy,
      );

    for (int i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final middle = (a.dx + b.dx) / 2;

      linePath.cubicTo(
        middle,
        a.dy,
        middle,
        b.dy,
        b.dx,
        b.dy,
      );
    }

    final fillPath = Path.from(linePath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x558B5CF6),
          Color(0x008B5CF6),
        ],
      ).createShader(
        Offset.zero & size,
      );

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFA78BFA),
          Color(0xFF3B82F6),
        ],
      ).createShader(
        Offset.zero & size,
      );

    canvas.drawPath(fillPath, fill);
    canvas.drawPath(linePath, line);

    for (final point in points) {
      canvas.drawCircle(
        point,
        3,
        Paint()..color = const Color(0xFFC4B5FD),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final values = [
      .22,
      .34,
      .29,
      .43,
      .52,
      .68,
      .94,
      .78,
      .41,
    ];

    final labels = [
      '6',
      '8',
      '10',
      '12',
      '14',
      '16',
      '18',
      '20',
      '22',
    ];

    final slot = size.width / values.length;
    final width = slot * .46;

    for (int i = 0; i < values.length; i++) {
      final x = i * slot + (slot - width) / 2;
      final height = size.height * .75 * values[i];

      final rect = Rect.fromLTWH(
        x,
        size.height - height - 22,
        width,
        height,
      );

      final paint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            AppColors.blue,
            AppColors.purple,
          ],
        ).createShader(rect);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect,
          const Radius.circular(6),
        ),
        paint,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            color: Color(0xFF697287),
            fontSize: 8,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(
        canvas,
        Offset(
          x + width / 2 - tp.width / 2,
          size.height - 15,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

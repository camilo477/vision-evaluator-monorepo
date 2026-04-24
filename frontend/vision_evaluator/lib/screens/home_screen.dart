import 'package:flutter/material.dart';
import 'model_selection_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const _AppBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: _HeroSection(theme: theme),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  flex: 5,
                                  child: _StartPanel(theme: theme),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                _HeroSection(theme: theme),
                                const SizedBox(height: 24),
                                _StartPanel(theme: theme),
                              ],
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final ThemeData theme;

  const _HeroSection({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.85),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: const Text(
            'Evaluación comparativa de modelos',
            style: TextStyle(
              color: Color(0xFF93C5FD),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Vision\nEvaluator',
          style: theme.textTheme.headlineLarge?.copyWith(
            fontSize: 48,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Text(
            'Una interfaz moderna para comparar algoritmos de visión por computador a partir de una misma imagen, visualizando métricas, resultados parciales y el mejor modelo de forma clara.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFFCBD5E1),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: const [
            _InfoPill(
              icon: Icons.center_focus_strong_rounded,
              text: 'Detección por imagen',
            ),
            _InfoPill(
              icon: Icons.model_training_rounded,
              text: 'Comparación entre modelos',
            ),
            _InfoPill(
              icon: Icons.insights_rounded,
              text: 'Métricas de desempeño',
            ),
          ],
        ),
        const SizedBox(height: 28),
        const _FeatureGrid(),
      ],
    );
  }
}

class _StartPanel extends StatelessWidget {
  final ThemeData theme;

  const _StartPanel({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF263244)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xCC111827), Color(0xCC0F172A)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 32,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 240,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              ),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Center(
              child: Image.asset(
                'assets/vision_logo.png',
                height: 150,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Iniciar evaluación',
            style: theme.textTheme.headlineMedium?.copyWith(fontSize: 26),
          ),
          const SizedBox(height: 12),
          Text(
            'Selecciona modelos, captura o carga una imagen y revisa la comparación de resultados en una sola experiencia.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Comenzar'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ModelSelectionScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Preparar evaluación'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ModelSelectionScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: const [
        _FeatureCard(
          icon: Icons.layers_rounded,
          title: 'Selección guiada',
          description:
              'Organiza modelos por categoría y facilita la preparación de la prueba.',
        ),
        _FeatureCard(
          icon: Icons.photo_camera_back_rounded,
          title: 'Entrada de imagen',
          description:
              'Captura desde cámara o carga una imagen existente desde el dispositivo.',
        ),
        _FeatureCard(
          icon: Icons.bar_chart_rounded,
          title: 'Resultados comparables',
          description:
              'Muestra confianza, detecciones y tiempos por cada modelo evaluado.',
        ),
        _FeatureCard(
          icon: Icons.emoji_events_rounded,
          title: 'Mejor modelo',
          description:
              'Resalta automáticamente el resultado más sólido para la evaluación.',
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xAA0F172A),
        border: Border.all(color: const Color(0xFF263244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [Color(0xFF4338CA), Color(0xFF06B6D4)],
              ),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(color: Color(0xFF94A3B8), height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xAA0F172A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF67E8F9)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFFE2E8F0),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppBackground extends StatelessWidget {
  const _AppBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.6, -0.8),
                radius: 1.3,
                colors: [
                  Color(0xFF1E1B4B),
                  Color(0xFF0B1120),
                  Color(0xFF070B14),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -80,
          right: -30,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF4F46E5).withOpacity(0.20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withOpacity(0.22),
                  blurRadius: 120,
                  spreadRadius: 40,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: -60,
          left: -20,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF06B6D4).withOpacity(0.12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF06B6D4).withOpacity(0.18),
                  blurRadius: 120,
                  spreadRadius: 30,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

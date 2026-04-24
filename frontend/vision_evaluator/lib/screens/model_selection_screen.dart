import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/model_option.dart';
import '../services/api_service.dart';
import 'camera_screen.dart';
import 'results_screen.dart';

class ModelSelectionScreen extends StatefulWidget {
  const ModelSelectionScreen({super.key});

  @override
  State<ModelSelectionScreen> createState() => _ModelSelectionScreenState();
}

class _ModelSelectionScreenState extends State<ModelSelectionScreen> {
  List<ModelOption> allModels = [];
  List<ModelOption> filteredModels = [];
  Map<String, bool> selectedModels = {};

  String selectedCategory = 'OBJECTS';

  bool isLoading = true;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    loadModels();
  }

  Future<void> loadModels() async {
    try {
      final result = await ApiService.fetchModels();

      setState(() {
        allModels = result;
        selectedModels = {for (var m in allModels) m.name: false};
        filterCategory('OBJECTS');
        isLoading = false;
      });
    } catch (e) {
      debugPrint('ERROR loading models: $e');
      setState(() {
        hasError = true;
        isLoading = false;
      });
    }
  }

  void filterCategory(String category) {
    setState(() {
      selectedCategory = category;
      filteredModels = allModels.where((m) => m.type == category).toList();
    });
  }

  Future<void> pickImageFromGallery(List<String> models) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked == null) return;

    if (kIsWeb) {
      final bytes = await picked.readAsBytes();

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultsScreen(
            selectedModels: models,
            imageBytes: bytes,
            imageFile: null,
          ),
        ),
      );
    } else {
      final file = File(picked.path);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultsScreen(
            selectedModels: models,
            imageFile: file,
            imageBytes: null,
          ),
        ),
      );
    }
  }

  void continueToCamera() {
    final chosen = _selectedModelNames;

    if (chosen.isEmpty) {
      _showMessage('Selecciona al menos un modelo.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScreen(
          onPictureTaken: (imageFile, imageBytes) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ResultsScreen(
                  selectedModels: chosen,
                  imageFile: imageFile,
                  imageBytes: imageBytes,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<String> get _selectedModelNames =>
      selectedModels.entries.where((e) => e.value).map((e) => e.key).toList();

  int get _selectedCount => _selectedModelNames.length;

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'OBJECTS':
        return 'Objetos';
      case 'TEXT':
        return 'Texto';
      case 'CODES':
        return 'Códigos';
      default:
        return category;
    }
  }

  String _categoryDescription(String category) {
    switch (category) {
      case 'OBJECTS':
        return 'Modelos para detección de objetos en escenas o fotografías.';
      case 'TEXT':
        return 'Modelos enfocados en reconocimiento o lectura de texto.';
      case 'CODES':
        return 'Modelos para lectura de códigos de barras o QR.';
      default:
        return 'Selecciona los modelos que deseas evaluar.';
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'OBJECTS':
        return Icons.category_rounded;
      case 'TEXT':
        return Icons.text_fields_rounded;
      case 'CODES':
        return Icons.qr_code_scanner_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  Color _categoryAccent(String category) {
    switch (category) {
      case 'OBJECTS':
        return const Color(0xFF2563EB);
      case 'TEXT':
        return const Color(0xFF7C3AED);
      case 'CODES':
        return const Color(0xFF059669);
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  void _toggleModel(String modelName, bool value) {
    setState(() {
      selectedModels[modelName] = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedNames = _selectedModelNames;
    final accent = _categoryAccent(selectedCategory);

    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Selección de modelos')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No fue posible cargar los modelos disponibles.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Revisa la conexión con el backend e inténtalo nuevamente.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          isLoading = true;
                          hasError = false;
                        });
                        loadModels();
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Selección de modelos')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 860;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: _buildMainContent(
                                theme,
                                accent,
                                selectedNames,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 4,
                              child: _buildSidePanel(theme, selectedNames),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _buildMainContent(theme, accent, selectedNames),
                            const SizedBox(height: 16),
                            _buildSidePanel(theme, selectedNames),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMainContent(
    ThemeData theme,
    Color accent,
    List<String> selectedNames,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configura la evaluación',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Selecciona la categoría de análisis y marca uno o varios modelos para compararlos con la misma imagen.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _CategoryCard(
                      title: _categoryLabel('OBJECTS'),
                      subtitle: 'Detección y análisis de objetos',
                      icon: _categoryIcon('OBJECTS'),
                      active: selectedCategory == 'OBJECTS',
                      color: _categoryAccent('OBJECTS'),
                      onTap: () => filterCategory('OBJECTS'),
                    ),
                    _CategoryCard(
                      title: _categoryLabel('TEXT'),
                      subtitle: 'Lectura o reconocimiento de texto',
                      icon: _categoryIcon('TEXT'),
                      active: selectedCategory == 'TEXT',
                      color: _categoryAccent('TEXT'),
                      onTap: () => filterCategory('TEXT'),
                    ),
                    _CategoryCard(
                      title: _categoryLabel('CODES'),
                      subtitle: 'Lectura de QR o códigos de barras',
                      icon: _categoryIcon('CODES'),
                      active: selectedCategory == 'CODES',
                      color: _categoryAccent('CODES'),
                      onTap: () => filterCategory('CODES'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_categoryIcon(selectedCategory), color: accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _categoryLabel(selectedCategory),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${filteredModels.length} disponibles',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _categoryDescription(selectedCategory),
                  style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
                ),
                const SizedBox(height: 18),
                if (filteredModels.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text(
                      'No hay modelos disponibles en esta categoría.',
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  ...filteredModels.map(
                    (model) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ModelOptionCard(
                        model: model,
                        isSelected: selectedModels[model.name] ?? false,
                        accent: accent,
                        onChanged: (value) => _toggleModel(model.name, value),
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

  Widget _buildSidePanel(ThemeData theme, List<String> selectedNames) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen de selección',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Has seleccionado $_selectedCount ${_selectedCount == 1 ? 'modelo' : 'modelos'} para evaluar.',
              style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Categoría activa',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _categoryLabel(selectedCategory),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (selectedNames.isNotEmpty) ...[
              const Text(
                'Modelos elegidos',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: selectedNames
                    .map(
                      (name) => Chip(
                        label: Text(name),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Text(
                  'Aún no has seleccionado modelos. Marca uno o varios para continuar.',
                  style: TextStyle(
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'Siguiente paso',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Continúa con la cámara o carga una imagen desde tu dispositivo para iniciar la comparación.',
              style: TextStyle(color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: continueToCamera,
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Usar cámara'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                final chosen = _selectedModelNames;

                if (chosen.isEmpty) {
                  _showMessage('Selecciona al menos un modelo.');
                  return;
                }

                pickImageFromGallery(chosen);
              },
              icon: const Icon(Icons.photo_library_rounded),
              label: const Text('Cargar imagen'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final background = active ? color.withValues(alpha: 0.10) : Colors.white;
    final borderColor = active ? color : const Color(0xFFE2E8F0);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 220,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: active ? color : const Color(0xFF475569)),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: active ? color : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF64748B), height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelOptionCard extends StatelessWidget {
  final ModelOption model;
  final bool isSelected;
  final Color accent;
  final ValueChanged<bool> onChanged;

  const _ModelOptionCard({
    required this.model,
    required this.isSelected,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: isSelected ? accent.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? accent : const Color(0xFFE2E8F0),
          width: isSelected ? 1.4 : 1,
        ),
      ),
      child: SwitchListTile(
        value: isSelected,
        onChanged: onChanged,
        title: Text(
          model.name,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        subtitle: Text(
          isSelected
              ? '${model.description} Incluido en la comparación.'
              : model.description,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import '../services/api_service.dart';
import '../services/report_downloader.dart';

class ResultsScreen extends StatefulWidget {
  final File? imageFile;
  final Uint8List? imageBytes;
  final List<String> selectedModels;

  const ResultsScreen({
    super.key,
    required this.selectedModels,
    this.imageFile,
    this.imageBytes,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  static const _lightingOptions = [
    'Luz optima',
    'Baja iluminacion',
    'Condiciones extremas',
  ];
  static const _distanceOptions = ['Corta', 'Media', 'Larga'];
  static const _complexityOptions = ['Baja', 'Media', 'Alta'];

  bool isSending = false;
  bool isSocketConnected = false;

  socket_io.Socket? socket;
  String? clientId;

  final List<Map<String, dynamic>> partialResults = [];
  final List<_EvaluationHistoryItem> history = [];
  final TextEditingController notesController = TextEditingController();
  final TextEditingController groundTruthController = TextEditingController();

  Map<String, dynamic>? finalResult;
  Map<String, dynamic>? lastHttpResponse;
  String lightingCondition = _lightingOptions.first;
  String distanceCondition = _distanceOptions[1];
  String complexityCondition = _complexityOptions[1];
  int runCounter = 0;

  @override
  void initState() {
    super.initState();
    _initSocket();
  }

  @override
  void dispose() {
    socket?.disconnect();
    socket?.close();
    notesController.dispose();
    groundTruthController.dispose();
    super.dispose();
  }

  void _initSocket() {
    socket = socket_io.io(
      ApiService.baseUrl,
      socket_io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .build(),
    );

    socket!.onConnect((_) {
      if (!mounted) return;
      setState(() {
        isSocketConnected = true;
        clientId = socket!.id;
      });
    });

    socket!.onDisconnect((_) {
      if (!mounted) return;
      setState(() {
        isSocketConnected = false;
      });
    });

    socket!.on('modelResult', (data) {
      if (data is Map) {
        setState(() {
          partialResults.add(_asStringMap(data));
        });
      }
    });

    socket!.on('finalResult', (data) {
      if (!mounted) return;
      final comparison = data is Map ? _asStringMap(data) : <String, dynamic>{};

      setState(() {
        finalResult = comparison;
        isSending = false;
        _storeHistory(comparison);
      });
    });

    socket!.onError((err) {
      debugPrint('SOCKET ERROR: $err');
    });

    socket!.connect();
  }

  static Map<String, dynamic> _asStringMap(Map<dynamic, dynamic> source) {
    return source.map((key, value) => MapEntry(key.toString(), value));
  }

  Map<String, dynamic> _mapOf(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return _asStringMap(value);
    return <String, dynamic>{};
  }

  List<dynamic> _listOf(dynamic value) {
    if (value is List) return value;
    return const [];
  }

  Map<String, String> get _conditions => {
    'Iluminacion': lightingCondition,
    'Distancia': distanceCondition,
    'Complejidad': complexityCondition,
    'Notas': notesController.text.trim().isEmpty
        ? 'Sin notas'
        : notesController.text.trim(),
  };

  List<String> get _groundTruthLabels => groundTruthController.text
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

  void _storeHistory(Map<String, dynamic> comparison) {
    runCounter += 1;
    history.insert(
      0,
      _EvaluationHistoryItem(
        number: runCounter,
        createdAt: DateTime.now(),
        models: List<String>.from(widget.selectedModels),
        conditions: Map<String, String>.from(_conditions),
        groundTruthLabels: List<String>.from(_groundTruthLabels),
        finalResult: Map<String, dynamic>.from(comparison),
        partialResults: partialResults
            .map((item) => Map<String, dynamic>.from(item))
            .toList(),
      ),
    );
  }

  Widget _buildImagePreview() {
    final imageInfo = _currentImageInfo();
    final boxes = _currentBoxes();
    final image = _imageWidget();

    if (image == null) {
      return const Center(child: Text('No hay imagen disponible.'));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 320,
        width: double.infinity,
        color: Colors.black,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(child: image),
                if (imageInfo != null && boxes.isNotEmpty)
                  CustomPaint(
                    painter: _BoundingBoxPainter(
                      imageWidth: imageInfo.width,
                      imageHeight: imageInfo.height,
                      boxes: boxes,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget? _imageWidget() {
    if (kIsWeb) {
      if (widget.imageBytes == null) return null;
      return Image.memory(widget.imageBytes!, fit: BoxFit.contain);
    }

    if (widget.imageFile == null) return null;
    return Image.file(widget.imageFile!, fit: BoxFit.contain);
  }

  Future<void> _sendToBackend() async {
    if (!isSocketConnected || clientId == null) {
      _showMessage(
        'La conexion con el servidor aun no esta lista. Intenta nuevamente.',
      );
      return;
    }

    setState(() {
      isSending = true;
      partialResults.clear();
      finalResult = null;
      lastHttpResponse = null;
    });

    try {
      final response = await ApiService.processImage(
        models: widget.selectedModels,
        imageFile: widget.imageFile,
        imageBytes: widget.imageBytes,
        clientId: clientId!,
        groundTruthLabels: _groundTruthLabels,
      );

      setState(() {
        lastHttpResponse = response;
      });
    } catch (e) {
      setState(() => isSending = false);
      _showMessage('Error enviando imagen: $e');
    }
  }

  Future<void> _downloadReport() async {
    if (finalResult == null) {
      _showMessage('Ejecuta una evaluacion antes de generar el reporte.');
      return;
    }

    final fileName =
        'vision_evaluation_${DateTime.now().millisecondsSinceEpoch}.csv';
    final path = await saveReport(fileName, _buildCsvReport());
    _showMessage(kIsWeb ? 'Reporte descargado.' : 'Reporte guardado en $path');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  double _progressValue() {
    if (widget.selectedModels.isEmpty) return 0;
    if (finalResult != null) return 1;

    final processed = partialResults.length.clamp(
      0,
      widget.selectedModels.length,
    );
    return processed / widget.selectedModels.length;
  }

  String _processingStatusText() {
    if (finalResult != null) return 'Evaluacion finalizada';
    if (isSending) return 'Procesando modelos seleccionados...';
    return 'Listo para iniciar la evaluacion';
  }

  String _connectionLabel() {
    return isSocketConnected ? 'Conectado' : 'Conectando...';
  }

  Color _connectionColor() {
    return isSocketConnected
        ? const Color(0xFF059669)
        : const Color(0xFFD97706);
  }

  num _toNum(dynamic value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatPercentage(dynamic value) {
    final numeric = _toNum(value);
    final percent = numeric <= 1 ? numeric * 100 : numeric;
    return '${percent.toStringAsFixed(2)}%';
  }

  String _formatMs(dynamic value) {
    return '${_toNum(value).toStringAsFixed(0)} ms';
  }

  String _formatFps(dynamic value) {
    return '${_toNum(value).toStringAsFixed(2)} FPS';
  }

  String _formatMb(dynamic value) {
    return '${_toNum(value).toStringAsFixed(1)} MB';
  }

  int _detectionsFromResult(Map<String, dynamic> item) {
    final result = _mapOf(item['result']);
    if (result['detectionsCount'] != null) {
      return _toNum(result['detectionsCount']).toInt();
    }

    return _listOf(result['detections']).length;
  }

  num _confidenceValueFromResult(Map<String, dynamic> item) {
    final result = _mapOf(item['result']);
    if (result['accuracy'] != null) return _toNum(result['accuracy']);
    if (result['confidence'] != null) return _toNum(result['confidence']);

    final detections = _listOf(result['detections']);
    num best = 0;
    for (final detection in detections) {
      final confidence = _toNum(_mapOf(detection)['confidence']);
      if (confidence > best) best = confidence;
    }
    return best;
  }

  String _confidenceFromResult(Map<String, dynamic> item) {
    if (_mapOf(item['result'])['error'] != null) return 'Error';
    final value = _confidenceValueFromResult(item);
    return value == 0 ? 'Sin dato' : _formatPercentage(value);
  }

  Map<String, dynamic> _metricsFromResult(Map<String, dynamic> item) {
    return _mapOf(_mapOf(item['result'])['metrics']);
  }

  Map<String, dynamic> _resourcesFromResult(Map<String, dynamic> item) {
    return _mapOf(_mapOf(item['result'])['resourceMetrics']);
  }

  Map<String, dynamic> _evaluationFromResult(Map<String, dynamic> item) {
    return _mapOf(_mapOf(item['result'])['evaluation']);
  }

  Map<String, dynamic> _finalEvaluation() {
    return _mapOf(finalResult?['evaluation']);
  }

  bool get _hasGroundTruth {
    final method = finalResult?['accuracyMethod']?.toString();
    return _groundTruthLabels.isNotEmpty || method == 'ground_truth_f1';
  }

  String _evaluationValue(
    Map<String, dynamic> item,
    String key, {
    bool percentage = true,
  }) {
    final evaluation = _evaluationFromResult(item);
    if (!evaluation.containsKey(key)) return 'Sin dato';

    final value = evaluation[key];
    return percentage ? _formatPercentage(value) : '${_toNum(value).toInt()}';
  }

  String _inferenceFromResult(Map<String, dynamic> item) {
    final metrics = _metricsFromResult(item);
    if (metrics['inferenceMs'] != null) {
      return _formatMs(metrics['inferenceMs']);
    }
    return 'Sin dato';
  }

  String _fpsFromResult(Map<String, dynamic> item) {
    final result = _mapOf(item['result']);
    if (result['fps'] != null) return _formatFps(result['fps']);

    final inferenceMs = _toNum(_metricsFromResult(item)['inferenceMs']);
    return inferenceMs > 0 ? _formatFps(1000 / inferenceMs) : 'Sin dato';
  }

  String _cpuFromResult(Map<String, dynamic> item) {
    final resources = _resourcesFromResult(item);
    if (resources['cpuPercent'] != null) {
      return _formatPercentage(resources['cpuPercent']);
    }
    return 'Sin dato';
  }

  String _memoryFromResult(Map<String, dynamic> item) {
    final resources = _resourcesFromResult(item);
    if (resources['memoryRssMb'] != null) {
      return _formatMb(resources['memoryRssMb']);
    }
    return 'Sin dato';
  }

  _ImageInfo? _currentImageInfo() {
    final source = _resultForOverlay();
    final imageInfo = _mapOf(_mapOf(source?['result'])['imageInfo']);
    final width = _toNum(imageInfo['width']).toDouble();
    final height = _toNum(imageInfo['height']).toDouble();

    if (width <= 0 || height <= 0) return null;
    return _ImageInfo(width: width, height: height);
  }

  Map<String, dynamic>? _resultForOverlay() {
    if (partialResults.isEmpty) return null;

    final bestModel = finalResult?['bestModel']?.toString();
    if (bestModel != null && bestModel != 'N/A') {
      for (final item in partialResults) {
        if (item['model']?.toString() == bestModel) return item;
      }
    }

    for (final item in partialResults) {
      if (_detectionsFromResult(item) > 0) return item;
    }

    return partialResults.first;
  }

  List<_DetectedBox> _currentBoxes() {
    final source = _resultForOverlay();
    if (source == null) return const [];

    final modelName = source['model']?.toString() ?? 'Modelo';
    final detections = _listOf(_mapOf(source['result'])['detections']);
    final boxes = <_DetectedBox>[];

    for (final detection in detections) {
      final map = _mapOf(detection);
      final xMin = _coordinate(map, 'xMin', 'x_min');
      final yMin = _coordinate(map, 'yMin', 'y_min');
      final xMax = _coordinate(map, 'xMax', 'x_max');
      final yMax = _coordinate(map, 'yMax', 'y_max');
      final width = xMax - xMin;
      final height = yMax - yMin;

      if (width <= 0 || height <= 0) continue;

      boxes.add(
        _DetectedBox(
          modelName: modelName,
          label: map['className']?.toString() ?? 'Objeto',
          confidence: _toNum(map['confidence']).toDouble(),
          rect: Rect.fromLTRB(xMin, yMin, xMax, yMax),
        ),
      );
    }

    boxes.sort((a, b) => b.confidence.compareTo(a.confidence));
    return boxes.take(12).toList();
  }

  double _coordinate(Map<String, dynamic> map, String camel, String snake) {
    return _toNum(map[camel] ?? map[snake]).toDouble();
  }

  List<_ChartMetric> _chartMetrics(_MetricKind kind) {
    return partialResults.map((item) {
      final modelName = item['model']?.toString() ?? 'Modelo';
      switch (kind) {
        case _MetricKind.confidence:
          return _ChartMetric(
            name: modelName,
            value: _confidenceValueFromResult(item).toDouble(),
            label: _formatPercentage(_confidenceValueFromResult(item)),
          );
        case _MetricKind.f1:
          final value = _toNum(_evaluationFromResult(item)['f1']);
          return _ChartMetric(
            name: modelName,
            value: value.toDouble(),
            label: _formatPercentage(value),
          );
        case _MetricKind.inference:
          final value = _toNum(_metricsFromResult(item)['inferenceMs']);
          return _ChartMetric(
            name: modelName,
            value: value.toDouble(),
            label: _formatMs(value),
          );
        case _MetricKind.fps:
          final result = _mapOf(item['result']);
          final value = result['fps'] != null
              ? _toNum(result['fps'])
              : _toNum(_metricsFromResult(item)['inferenceMs']) > 0
              ? 1000 / _toNum(_metricsFromResult(item)['inferenceMs'])
              : 0;
          return _ChartMetric(
            name: modelName,
            value: value.toDouble(),
            label: _formatFps(value),
          );
        case _MetricKind.detections:
          final value = _detectionsFromResult(item);
          return _ChartMetric(
            name: modelName,
            value: value.toDouble(),
            label: '$value',
          );
      }
    }).toList();
  }

  String _buildCsvReport() {
    final lines = <List<String>>[
      ['Reporte Vision Evaluator'],
      ['Fecha', DateTime.now().toIso8601String()],
      ['Modelos', widget.selectedModels.join(' | ')],
      ['Ground truth', _groundTruthLabels.join(' | ')],
      [],
      ['Condiciones'],
      ..._conditions.entries.map((entry) => [entry.key, entry.value]),
      [],
      ['Resumen final'],
      ['Mejor modelo', finalResult?['bestModel']?.toString() ?? 'N/A'],
      [
        finalResult?['accuracyMethod'] == 'ground_truth_f1'
            ? 'F1 ground truth'
            : 'Confianza',
        _formatPercentage(finalResult?['accuracy']),
      ],
      ['FPS', _formatFps(finalResult?['fps'])],
      ['Detecciones', '${finalResult?['detectionsCount'] ?? 0}'],
      [],
      [
        'Modelo',
        'Confianza',
        'Precision GT',
        'Recall GT',
        'F1 GT',
        'TP',
        'FP',
        'FN',
        'Detecciones',
        'Inferencia ms',
        'Total ms',
        'FPS',
        'CPU backend %',
        'Memoria backend MB',
        'Error',
      ],
    ];

    for (final item in partialResults) {
      final result = _mapOf(item['result']);
      final metrics = _metricsFromResult(item);
      final resources = _resourcesFromResult(item);
      final evaluation = _evaluationFromResult(item);

      lines.add([
        item['model']?.toString() ?? '',
        _formatPercentage(_confidenceValueFromResult(item)),
        '${_toNum(evaluation['precision'])}',
        '${_toNum(evaluation['recall'])}',
        '${_toNum(evaluation['f1'])}',
        '${_toNum(evaluation['truePositives']).toInt()}',
        '${_toNum(evaluation['falsePositives']).toInt()}',
        '${_toNum(evaluation['falseNegatives']).toInt()}',
        '${_detectionsFromResult(item)}',
        '${_toNum(metrics['inferenceMs'])}',
        '${_toNum(metrics['totalMs'])}',
        '${_toNum(result['fps'])}',
        '${_toNum(resources['cpuPercent'])}',
        '${_toNum(resources['memoryRssMb'])}',
        result['error']?.toString() ?? '',
      ]);
    }

    return lines.map(_csvLine).join('\n');
  }

  String _csvLine(List<String> cells) {
    return cells
        .map((cell) {
          final escaped = cell.replaceAll('"', '""');
          return '"$escaped"';
        })
        .join(',');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _progressValue();

    return Scaffold(
      appBar: AppBar(title: const Text('Resultados')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Imagen evaluada',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildImagePreview(),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.selectedModels
                              .map((model) => Chip(label: Text(model)))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildConditionsCard(theme),
                  const SizedBox(height: 16),
                  _buildProcessingCard(theme, progress),
                  const SizedBox(height: 16),
                  _buildModelResultsCard(theme),
                  if (partialResults.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildChartsCard(theme),
                  ],
                  if (finalResult != null) ...[
                    const SizedBox(height: 16),
                    _buildBestModelCard(theme),
                    const SizedBox(height: 16),
                    _buildComparisonCard(theme),
                  ],
                  if (history.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildHistoryCard(theme),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConditionsCard(ThemeData theme) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Condiciones de prueba',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ConditionDropdown(
                label: 'Iluminacion',
                value: lightingCondition,
                values: _lightingOptions,
                onChanged: (value) => setState(() => lightingCondition = value),
              ),
              _ConditionDropdown(
                label: 'Distancia',
                value: distanceCondition,
                values: _distanceOptions,
                onChanged: (value) => setState(() => distanceCondition = value),
              ),
              _ConditionDropdown(
                label: 'Complejidad',
                value: complexityCondition,
                values: _complexityOptions,
                onChanged: (value) =>
                    setState(() => complexityCondition = value),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: groundTruthController,
            decoration: const InputDecoration(
              labelText: 'Ground truth por etiquetas',
              hintText: 'Ejemplo: persona, carro, botella',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: notesController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Notas del escenario',
              hintText: 'Ejemplo: interior, fondo complejo, objeto lejano',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingCard(ThemeData theme, double progress) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estado del procesamiento',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _connectionColor(),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Servidor: ${_connectionLabel()}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: isSending || finalResult != null ? progress : 0,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _processingStatusText(),
            style: const TextStyle(
              color: Color(0xFF475569),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${partialResults.length} de ${widget.selectedModels.length} modelos procesados',
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 220,
                child: ElevatedButton.icon(
                  onPressed: isSending ? null : _sendToBackend,
                  icon: isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_graph_rounded),
                  label: Text(isSending ? 'Procesando...' : 'Procesar imagen'),
                ),
              ),
              SizedBox(
                width: 220,
                child: OutlinedButton.icon(
                  onPressed: finalResult == null ? null : _downloadReport,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Descargar CSV'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModelResultsCard(ThemeData theme) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resultados por modelo',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          if (partialResults.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: _softPanelDecoration(),
              child: const Text(
                'Aqui apareceran los resultados parciales de cada modelo durante la evaluacion.',
                style: TextStyle(color: Color(0xFF64748B), height: 1.4),
              ),
            )
          else
            Column(
              children: partialResults
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ModelResultCard(
                        modelName: item['model']?.toString() ?? 'Modelo',
                        confidence: _confidenceFromResult(item),
                        detections: _detectionsFromResult(item).toString(),
                        inference: _inferenceFromResult(item),
                        fps: _fpsFromResult(item),
                        cpu: _cpuFromResult(item),
                        memory: _memoryFromResult(item),
                        precision: _evaluationValue(item, 'precision'),
                        recall: _evaluationValue(item, 'recall'),
                        f1: _evaluationValue(item, 'f1'),
                        truePositives: _evaluationValue(
                          item,
                          'truePositives',
                          percentage: false,
                        ),
                        falsePositives: _evaluationValue(
                          item,
                          'falsePositives',
                          percentage: false,
                        ),
                        falseNegatives: _evaluationValue(
                          item,
                          'falseNegatives',
                          percentage: false,
                        ),
                        showGroundTruth: _hasGroundTruth,
                        error: _mapOf(item['result'])['error']?.toString(),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildChartsCard(ThemeData theme) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Graficas comparativas',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          if (_hasGroundTruth) ...[
            _MetricBarChart(
              title: 'F1 con ground truth',
              metrics: _chartMetrics(_MetricKind.f1),
            ),
            const SizedBox(height: 18),
          ],
          _MetricBarChart(
            title: 'Confianza',
            metrics: _chartMetrics(_MetricKind.confidence),
          ),
          const SizedBox(height: 18),
          _MetricBarChart(
            title: 'Tiempo de inferencia',
            metrics: _chartMetrics(_MetricKind.inference),
          ),
          const SizedBox(height: 18),
          _MetricBarChart(
            title: 'FPS derivado',
            metrics: _chartMetrics(_MetricKind.fps),
          ),
          const SizedBox(height: 18),
          _MetricBarChart(
            title: 'Detecciones',
            metrics: _chartMetrics(_MetricKind.detections),
          ),
        ],
      ),
    );
  }

  Widget _buildBestModelCard(ThemeData theme) {
    final result = finalResult ?? {};
    final metrics = _mapOf(result['metrics']);
    final resources = _mapOf(result['resourceMetrics']);
    final evaluation = _finalEvaluation();

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mejor modelo',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFECFDF5), Color(0xFFF0FDF4)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.emoji_events_rounded, color: Color(0xFF059669)),
                    SizedBox(width: 8),
                    Text(
                      'Resultado destacado',
                      style: TextStyle(
                        color: Color(0xFF047857),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  result['bestModel']?.toString() ?? 'Sin dato',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF065F46),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricBadge(
                      label: _hasGroundTruth ? 'F1 ground truth' : 'Confianza',
                      value: _formatPercentage(result['accuracy']),
                    ),
                    if (_hasGroundTruth) ...[
                      _MetricBadge(
                        label: 'Precision',
                        value: _formatPercentage(evaluation['precision']),
                      ),
                      _MetricBadge(
                        label: 'Recall',
                        value: _formatPercentage(evaluation['recall']),
                      ),
                    ],
                    _MetricBadge(
                      label: 'Detecciones',
                      value: '${result['detectionsCount'] ?? 0}',
                    ),
                    _MetricBadge(
                      label: 'FPS',
                      value: _formatFps(result['fps']),
                    ),
                    _MetricBadge(
                      label: 'Tiempo total',
                      value: _formatMs(metrics['totalMs']),
                    ),
                    _MetricBadge(
                      label: 'Inferencia',
                      value: _formatMs(metrics['inferenceMs']),
                    ),
                    _MetricBadge(
                      label: 'CPU backend',
                      value: resources['cpuPercent'] == null
                          ? 'Sin dato'
                          : _formatPercentage(resources['cpuPercent']),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonCard(ThemeData theme) {
    final result = finalResult ?? {};
    final metrics = _mapOf(result['metrics']);
    final resources = _mapOf(result['resourceMetrics']);
    final evaluation = _finalEvaluation();

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comparacion general',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ComparisonCard(
                title: 'Mejor modelo',
                value: result['bestModel']?.toString() ?? '-',
                icon: Icons.star_rounded,
              ),
              _ComparisonCard(
                title: _hasGroundTruth ? 'F1 ground truth' : 'Confianza',
                value: _formatPercentage(result['accuracy']),
                icon: Icons.verified_rounded,
              ),
              if (_hasGroundTruth) ...[
                _ComparisonCard(
                  title: 'Precision',
                  value: _formatPercentage(evaluation['precision']),
                  icon: Icons.rule_rounded,
                ),
                _ComparisonCard(
                  title: 'Recall',
                  value: _formatPercentage(evaluation['recall']),
                  icon: Icons.manage_search_rounded,
                ),
              ],
              _ComparisonCard(
                title: 'Detecciones',
                value: '${result['detectionsCount'] ?? 0}',
                icon: Icons.center_focus_strong_rounded,
              ),
              _ComparisonCard(
                title: 'FPS',
                value: _formatFps(result['fps']),
                icon: Icons.speed_rounded,
              ),
              _ComparisonCard(
                title: 'Tiempo total',
                value: _formatMs(metrics['totalMs']),
                icon: Icons.schedule_rounded,
              ),
              _ComparisonCard(
                title: 'Inferencia',
                value: _formatMs(metrics['inferenceMs']),
                icon: Icons.bolt_rounded,
              ),
              _ComparisonCard(
                title: 'CPU backend',
                value: resources['cpuPercent'] == null
                    ? '-'
                    : _formatPercentage(resources['cpuPercent']),
                icon: Icons.memory_rounded,
              ),
              _ComparisonCard(
                title: 'RAM backend',
                value: resources['memoryRssMb'] == null
                    ? '-'
                    : _formatMb(resources['memoryRssMb']),
                icon: Icons.storage_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(ThemeData theme) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Historial de ejecuciones',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: history
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _HistoryTile(item: item),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  BoxDecoration _softPanelDecoration() {
    return BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(22), child: child),
    );
  }
}

class _ConditionDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  const _ConditionDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: values
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: (newValue) {
          if (newValue != null) onChanged(newValue);
        },
      ),
    );
  }
}

class _ModelResultCard extends StatelessWidget {
  final String modelName;
  final String confidence;
  final String detections;
  final String inference;
  final String fps;
  final String cpu;
  final String memory;
  final String precision;
  final String recall;
  final String f1;
  final String truePositives;
  final String falsePositives;
  final String falseNegatives;
  final bool showGroundTruth;
  final String? error;

  const _ModelResultCard({
    required this.modelName,
    required this.confidence,
    required this.detections,
    required this.inference,
    required this.fps,
    required this.cpu,
    required this.memory,
    required this.precision,
    required this.recall,
    required this.f1,
    required this.truePositives,
    required this.falsePositives,
    required this.falseNegatives,
    required this.showGroundTruth,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            modelName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              style: const TextStyle(
                color: Color(0xFFB91C1C),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricBadge(label: 'Confianza', value: confidence),
              if (showGroundTruth) ...[
                _MetricBadge(label: 'Precision', value: precision),
                _MetricBadge(label: 'Recall', value: recall),
                _MetricBadge(label: 'F1', value: f1),
                _MetricBadge(label: 'TP', value: truePositives),
                _MetricBadge(label: 'FP', value: falsePositives),
                _MetricBadge(label: 'FN', value: falseNegatives),
              ],
              _MetricBadge(label: 'Detecciones', value: detections),
              _MetricBadge(label: 'Inferencia', value: inference),
              _MetricBadge(label: 'FPS', value: fps),
              _MetricBadge(label: 'CPU backend', value: cpu),
              _MetricBadge(label: 'RAM backend', value: memory),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  final String label;
  final String value;

  const _MetricBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _ComparisonCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricBarChart extends StatelessWidget {
  final String title;
  final List<_ChartMetric> metrics;

  const _MetricBarChart({required this.title, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final maxValue = metrics.fold<double>(
      0,
      (current, item) => math.max(current, item.value),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (metrics.isEmpty)
            const Text('Sin datos disponibles.')
          else
            ...metrics.map(
              (metric) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MetricBar(metric: metric, maxValue: maxValue),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  final _ChartMetric metric;
  final double maxValue;

  const _MetricBar({required this.metric, required this.maxValue});

  @override
  Widget build(BuildContext context) {
    final factor = maxValue <= 0 ? 0.0 : (metric.value / maxValue).clamp(0, 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                metric.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              metric.label,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: factor.toDouble(),
            minHeight: 12,
            backgroundColor: const Color(0xFFE2E8F0),
          ),
        ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final _EvaluationHistoryItem item;

  const _HistoryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final bestModel = item.finalResult['bestModel']?.toString() ?? 'N/A';
    final confidence = item.finalResult['accuracy'] ?? 0;
    final method = item.finalResult['accuracyMethod']?.toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ejecucion ${item.number} - $bestModel',
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${item.createdAt.toLocal()}'.split('.').first,
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                label: Text(
                  '${method == 'ground_truth_f1' ? 'F1' : 'Confianza'} ${_formatStaticPercentage(confidence)}',
                ),
              ),
              if (item.groundTruthLabels.isNotEmpty)
                Chip(label: Text('GT ${item.groundTruthLabels.join(' | ')}')),
              Chip(label: Text(item.conditions['Iluminacion'] ?? '-')),
              Chip(label: Text(item.conditions['Distancia'] ?? '-')),
              Chip(label: Text(item.conditions['Complejidad'] ?? '-')),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatStaticPercentage(dynamic value) {
    final numeric = value is num ? value : num.tryParse('$value') ?? 0;
    final percent = numeric <= 1 ? numeric * 100 : numeric;
    return '${percent.toStringAsFixed(2)}%';
  }
}

class _BoundingBoxPainter extends CustomPainter {
  final double imageWidth;
  final double imageHeight;
  final List<_DetectedBox> boxes;

  const _BoundingBoxPainter({
    required this.imageWidth,
    required this.imageHeight,
    required this.boxes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageWidth <= 0 || imageHeight <= 0) return;

    final scale = math.min(size.width / imageWidth, size.height / imageHeight);
    final displayWidth = imageWidth * scale;
    final displayHeight = imageHeight * scale;
    final offset = Offset(
      (size.width - displayWidth) / 2,
      (size.height - displayHeight) / 2,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = const Color(0xFF22C55E);

    final labelBackground = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xDD052E16);

    for (final box in boxes) {
      final rect = Rect.fromLTRB(
        offset.dx + box.rect.left * scale,
        offset.dy + box.rect.top * scale,
        offset.dx + box.rect.right * scale,
        offset.dy + box.rect.bottom * scale,
      );

      canvas.drawRect(rect, paint);

      final label =
          '${box.label} ${(box.confidence * 100).toStringAsFixed(1)}%';
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: math.max(80, rect.width));

      final labelRect = Rect.fromLTWH(
        rect.left,
        math.max(0, rect.top - textPainter.height - 6),
        textPainter.width + 10,
        textPainter.height + 6,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(labelRect, const Radius.circular(6)),
        labelBackground,
      );
      textPainter.paint(canvas, labelRect.topLeft + const Offset(5, 3));
    }
  }

  @override
  bool shouldRepaint(covariant _BoundingBoxPainter oldDelegate) {
    return oldDelegate.boxes != boxes ||
        oldDelegate.imageWidth != imageWidth ||
        oldDelegate.imageHeight != imageHeight;
  }
}

enum _MetricKind { confidence, f1, inference, fps, detections }

class _ChartMetric {
  final String name;
  final double value;
  final String label;

  const _ChartMetric({
    required this.name,
    required this.value,
    required this.label,
  });
}

class _ImageInfo {
  final double width;
  final double height;

  const _ImageInfo({required this.width, required this.height});
}

class _DetectedBox {
  final String modelName;
  final String label;
  final double confidence;
  final Rect rect;

  const _DetectedBox({
    required this.modelName,
    required this.label,
    required this.confidence,
    required this.rect,
  });
}

class _EvaluationHistoryItem {
  final int number;
  final DateTime createdAt;
  final List<String> models;
  final Map<String, String> conditions;
  final List<String> groundTruthLabels;
  final Map<String, dynamic> finalResult;
  final List<Map<String, dynamic>> partialResults;

  const _EvaluationHistoryItem({
    required this.number,
    required this.createdAt,
    required this.models,
    required this.conditions,
    required this.groundTruthLabels,
    required this.finalResult,
    required this.partialResults,
  });
}

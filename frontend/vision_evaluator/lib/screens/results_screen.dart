import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../services/api_service.dart';

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
  bool isSending = false;
  bool isSocketConnected = false;

  IO.Socket? socket;
  String? clientId;

  final List<Map<String, dynamic>> partialResults = [];
  dynamic finalResult;
  Map<String, dynamic>? lastHttpResponse;

  @override
  void initState() {
    super.initState();
    _initSocket();
  }

  @override
  void dispose() {
    socket?.disconnect();
    socket?.close();
    super.dispose();
  }

  void _initSocket() {
    const socketUrl = 'http://192.168.10.48:3000';

    socket = IO.io(
      socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    socket!.onConnect((_) {
      setState(() {
        isSocketConnected = true;
        clientId = socket!.id;
      });
    });

    socket!.onDisconnect((_) {
      setState(() {
        isSocketConnected = false;
      });
    });

    socket!.on('modelResult', (data) {
      if (data is Map) {
        setState(() {
          partialResults.add(Map<String, dynamic>.from(data));
        });
      }
    });

    socket!.on('finalResult', (data) {
      setState(() {
        finalResult = data;
        isSending = false;
      });
    });

    socket!.onError((err) {
      debugPrint('SOCKET ERROR: $err');
    });

    socket!.connect();
  }

  Widget _buildImagePreview() {
    if (kIsWeb) {
      if (widget.imageBytes == null) {
        return const Center(child: Text('No hay imagen disponible.'));
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.memory(
          widget.imageBytes!,
          height: 260,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    } else {
      if (widget.imageFile == null) {
        return const Center(child: Text('No hay imagen disponible.'));
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.file(
          widget.imageFile!,
          height: 260,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }
  }

  Future<void> _sendToBackend() async {
    if (!isSocketConnected || clientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La conexión con el servidor aún no está lista. Intenta nuevamente en un momento.',
          ),
        ),
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
      );

      setState(() {
        lastHttpResponse = response;
      });
    } catch (e) {
      setState(() => isSending = false);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error enviando imagen: $e')));
    }
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
    if (finalResult != null) {
      return 'Evaluación finalizada';
    }
    if (isSending) {
      return 'Procesando modelos seleccionados...';
    }
    return 'Listo para iniciar la evaluación';
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
    final num numeric = _toNum(value);
    final percent = numeric <= 1 ? numeric * 100 : numeric;
    return '${percent.toStringAsFixed(2)}%';
  }

  String _formatMs(dynamic value) {
    final numeric = _toNum(value);
    return '${numeric.toStringAsFixed(0)} ms';
  }

  int _detectionsFromResult(Map<String, dynamic> item) {
    final result = item['result'];

    if (result is Map && result['detectionsCount'] != null) {
      return _toNum(result['detectionsCount']).toInt();
    }

    if (result is Map && result['detections'] is List) {
      return (result['detections'] as List).length;
    }

    return 0;
  }

  String _confidenceFromResult(Map<String, dynamic> item) {
    final result = item['result'];

    if (result is Map && result['accuracy'] != null) {
      return _formatPercentage(result['accuracy']);
    }

    if (result is Map && result['confidence'] != null) {
      return _formatPercentage(result['confidence']);
    }

    return 'Sin dato';
  }

  String _inferenceFromResult(Map<String, dynamic> item) {
    final result = item['result'];

    if (result is Map && result['metrics'] is Map) {
      final metrics = Map<String, dynamic>.from(result['metrics']);
      if (metrics['inferenceMs'] != null) {
        return _formatMs(metrics['inferenceMs']);
      }
    }

    return 'Sin dato';
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
                              .map((m) => Chip(label: Text(m)))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: isSending || finalResult != null
                                ? progress
                                : 0,
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
                        ElevatedButton.icon(
                          onPressed: isSending ? null : _sendToBackend,
                          icon: isSending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.auto_graph_rounded),
                          label: Text(
                            isSending ? 'Procesando...' : 'Procesar imagen',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
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
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: const Text(
                              'Aquí aparecerán los resultados parciales de cada modelo durante la evaluación.',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                height: 1.4,
                              ),
                            ),
                          )
                        else
                          Column(
                            children: partialResults
                                .map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _ModelResultCard(
                                      modelName:
                                          item['model']?.toString() ?? 'Modelo',
                                      confidence: _confidenceFromResult(item),
                                      detections: _detectionsFromResult(
                                        item,
                                      ).toString(),
                                      inference: _inferenceFromResult(item),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                  if (finalResult != null) ...[
                    const SizedBox(height: 16),
                    _SectionCard(
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
                              border: Border.all(
                                color: const Color(0xFFA7F3D0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.emoji_events_rounded,
                                      color: Color(0xFF059669),
                                    ),
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
                                  finalResult['bestModel']?.toString() ??
                                      'Sin dato',
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
                                      label: 'Confianza',
                                      value: _formatPercentage(
                                        finalResult['accuracy'],
                                      ),
                                    ),
                                    _MetricBadge(
                                      label: 'Detecciones',
                                      value:
                                          '${finalResult['detectionsCount'] ?? 0}',
                                    ),
                                    _MetricBadge(
                                      label: 'Tiempo total',
                                      value: finalResult['metrics'] != null
                                          ? _formatMs(
                                              finalResult['metrics']['totalMs'],
                                            )
                                          : 'Sin dato',
                                    ),
                                    _MetricBadge(
                                      label: 'Inferencia',
                                      value: finalResult['metrics'] != null
                                          ? _formatMs(
                                              finalResult['metrics']['inferenceMs'],
                                            )
                                          : 'Sin dato',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Comparación general',
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
                                value:
                                    finalResult['bestModel']?.toString() ?? '-',
                                icon: Icons.star_rounded,
                              ),
                              _ComparisonCard(
                                title: 'Confianza',
                                value: _formatPercentage(
                                  finalResult['accuracy'],
                                ),
                                icon: Icons.verified_rounded,
                              ),
                              _ComparisonCard(
                                title: 'Detecciones',
                                value: '${finalResult['detectionsCount'] ?? 0}',
                                icon: Icons.center_focus_strong_rounded,
                              ),
                              _ComparisonCard(
                                title: 'Tiempo total',
                                value: finalResult['metrics'] != null
                                    ? _formatMs(
                                        finalResult['metrics']['totalMs'],
                                      )
                                    : '-',
                                icon: Icons.schedule_rounded,
                              ),
                              _ComparisonCard(
                                title: 'Inferencia',
                                value: finalResult['metrics'] != null
                                    ? _formatMs(
                                        finalResult['metrics']['inferenceMs'],
                                      )
                                    : '-',
                                icon: Icons.bolt_rounded,
                              ),
                              _ComparisonCard(
                                title: 'Preprocesamiento',
                                value: finalResult['metrics'] != null
                                    ? _formatMs(
                                        finalResult['metrics']['preprocessMs'],
                                      )
                                    : '-',
                                icon: Icons.tune_rounded,
                              ),
                              _ComparisonCard(
                                title: 'Postprocesamiento',
                                value: finalResult['metrics'] != null
                                    ? _formatMs(
                                        finalResult['metrics']['postprocessMs'],
                                      )
                                    : '-',
                                icon: Icons.settings_suggest_rounded,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
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

class _ModelResultCard extends StatelessWidget {
  final String modelName;
  final String confidence;
  final String detections;
  final String inference;

  const _ModelResultCard({
    required this.modelName,
    required this.confidence,
    required this.detections,
    required this.inference,
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
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricBadge(label: 'Confianza', value: confidence),
              _MetricBadge(label: 'Detecciones', value: detections),
              _MetricBadge(label: 'Inferencia', value: inference),
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

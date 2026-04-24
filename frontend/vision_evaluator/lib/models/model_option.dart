class ModelOption {
  final String name;
  final String type;
  final String description;

  ModelOption({
    required this.name,
    required this.type,
    required this.description,
  });

  factory ModelOption.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? '';
    final type = json['type']?.toString() ?? '';

    return ModelOption(
      name: name,
      type: type,
      description: _descriptionFor(name, type),
    );
  }

  static String _descriptionFor(String name, String type) {
    switch (name) {
      case 'YOLOv8n':
        return 'Detector liviano de objetos con buena velocidad general.';
      case 'YOLOv5n':
        return 'Detector compacto de objetos basado en YOLOv5 nano.';
      case 'EfficientDet':
        return 'Detector de objetos eficiente con arquitectura EfficientDet-D0.';
      case 'MobileNet':
        return 'Clasificador ImageNet liviano para reconocer la clase principal.';
      case 'PaddleOCR':
        return 'OCR robusto para detectar y leer texto en imagenes.';
      case 'EasyOCR':
        return 'OCR practico multilenguaje para lectura general de texto.';
      case 'TesseractOCR':
        return 'OCR clasico basado en Tesseract para texto impreso.';
      case 'CRAFTCRNN':
        return 'Pipeline de deteccion CRAFT y reconocimiento CRNN para texto.';
      case 'ZBar':
        return 'Lector de codigos QR y barras usando ZBar.';
      case 'ZXing':
        return 'Lector de codigos basado en ZXing-cpp.';
      case 'pybarcode':
        return 'Lector compatible para comparar codigos usando OpenCV.';
      default:
        if (type == 'TEXT') return 'Modelo disponible para reconocimiento de texto.';
        if (type == 'CODES') return 'Modelo disponible para lectura de codigos.';
        return 'Modelo disponible para analisis de objetos.';
    }
  }
}

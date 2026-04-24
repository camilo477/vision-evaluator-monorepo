import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../models/model_option.dart';

class ApiService {
  // CAMBIAR PARA MÓVIL
  // - Emulador Android: http://10.0.2.2:3000
  // - Celular físico: http://TU_IP_LOCAL:3000
  // - Web / Linux: http://localhost:3000
  static const String baseUrl = "http://192.168.10.48:3000";

  static const List<Map<String, String>> expectedModels = [
    {'name': 'YOLOv8n', 'type': 'OBJECTS'},
    {'name': 'YOLOv5n', 'type': 'OBJECTS'},
    {'name': 'EfficientDet', 'type': 'OBJECTS'},
    {'name': 'MobileNet', 'type': 'OBJECTS'},
    {'name': 'PaddleOCR', 'type': 'TEXT'},
    {'name': 'EasyOCR', 'type': 'TEXT'},
    {'name': 'TesseractOCR', 'type': 'TEXT'},
    {'name': 'CRAFTCRNN', 'type': 'TEXT'},
    {'name': 'ZBar', 'type': 'CODES'},
    {'name': 'ZXing', 'type': 'CODES'},
    {'name': 'pybarcode', 'type': 'CODES'},
  ];

  static Future<List<ModelOption>> fetchModels() async {
    final url = Uri.parse("$baseUrl/image/models");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      final byName = <String, Map<String, dynamic>>{};

      for (final model in expectedModels) {
        byName[model['name']!] = Map<String, dynamic>.from(model);
      }

      for (final item in jsonList) {
        if (item is Map<String, dynamic>) {
          final name = item['name']?.toString();
          if (name != null && name.isNotEmpty) {
            byName[name] = item;
          }
        }
      }

      return byName.values.map(ModelOption.fromJson).toList();
    }

    throw Exception("Error fetching model list: ${response.statusCode}");
  }

  static Future<Map<String, dynamic>> processImage({
    required List<String> models,
    File? imageFile,
    Uint8List? imageBytes,
    required String clientId,
  }) async {
    final url = Uri.parse("$baseUrl/image/process");

    final request = http.MultipartRequest("POST", url);

    request.fields["clientId"] = clientId;
    request.fields["models"] = models.join(",");

    if (kIsWeb) {
      if (imageBytes == null) {
        throw Exception("Web: imageBytes is null");
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          "image",
          imageBytes,
          filename: "photo.jpg",
        ),
      );
    } else {
      if (imageFile == null) {
        throw Exception("Mobile/Desktop: imageFile is null");
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          "image",
          imageFile.path,
          filename: "photo.jpg",
        ),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    }

    print("ERROR BACKEND → ${response.body}");
    throw Exception("Error processing image: ${response.statusCode}");
  }
}

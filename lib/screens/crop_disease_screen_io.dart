import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../utils/app_theme.dart';

class CropDiseaseScreen extends StatefulWidget {
  const CropDiseaseScreen({super.key});

  @override
  State<CropDiseaseScreen> createState() => _CropDiseaseScreenState();
}

class _CropDiseaseScreenState extends State<CropDiseaseScreen> {
  final _picker = ImagePicker();
  File? _imageFile;
  String? _predictedLabel;
  double? _confidence;
  String? _matchedRemedyClass;
  Map<String, List<String>>? _matchedRemedies;
  String? _error;
  List<MapEntry<String, double>>? _topPredictions;
  bool _loadingModel = false;
  bool _running = false;
  Interpreter? _interpreter;
  List<String> _labels = [];
  final Map<String, Map<String, List<String>>> _remediesByNormalizedClass = {};
  final Map<String, String> _displayClassByNormalizedClass = {};
  static const List<String> _defaultLabels = [
    'Apple___Apple_scab',
    'Apple___Black_rot',
    'Apple___Cedar_apple_rust',
    'Apple___healthy',
    'Blueberry___healthy',
    'Cherry_(including_sour)___Powdery_mildew',
    'Cherry_(including_sour)___healthy',
    'Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot',
    'Corn_(maize)___Common_rust_',
    'Corn_(maize)___Northern_Leaf_Blight',
    'Corn_(maize)___healthy',
    'Grape___Black_rot',
    'Grape___Esca_(Black_Measles)',
    'Grape___Leaf_blight_(Isariopsis_Leaf_Spot)',
    'Grape___healthy',
    'Orange___Haunglongbing_(Citrus_greening)',
    'Peach___Bacterial_spot',
    'Peach___healthy',
    'Pepper,_bell___Bacterial_spot',
    'Pepper,_bell___healthy',
    'Potato___Early_blight',
    'Potato___Late_blight',
    'Potato___healthy',
    'Raspberry___healthy',
    'Soybean___healthy',
    'Squash___Powdery_mildew',
    'Strawberry___Leaf_scorch',
    'Strawberry___healthy',
    'Tomato___Bacterial_spot',
    'Tomato___Early_blight',
    'Tomato___Late_blight',
    'Tomato___Leaf_Mold',
    'Tomato___Septoria_leaf_spot',
    'Tomato___Spider_mites Two-spotted_spider_mite',
    'Tomato___Target_Spot',
    'Tomato___Tomato_Yellow_Leaf_Curl_Virus',
    'Tomato___Tomato_mosaic_virus',
    'Tomato___healthy',
  ];

  static const _modelAsset = 'assets/models/model.tflite';
  static const _labelsAsset = 'assets/models/labels.txt';
  static const _remediesAsset = 'assets/models/remedieses.json';
  static const List<String> _remedyCategories = [
    'chemical',
    'organic',
    'biological',
    'cultural',
    'mechanical',
  ];

  @override
  void initState() {
    super.initState();
    _loadModel();
    _loadRemedies();
  }

  Future<void> _loadRemedies() async {
    try {
      final raw = await rootBundle.loadString(_remediesAsset);
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid remedies JSON format.');
      }
      final data = decoded['data'];
      if (data is! List) {
        throw const FormatException('Expected "data" array in remedies JSON.');
      }

      for (final item in data) {
        if (item is! Map<String, dynamic>) continue;
        final diseaseClass = item['class']?.toString().trim();
        final remedies = item['remedies'];
        if (diseaseClass == null || diseaseClass.isEmpty || remedies is! Map) continue;

        final normalizedClass = _normalizeDiseaseName(diseaseClass);
        final remedyMap = <String, List<String>>{};
        for (final category in _remedyCategories) {
          final value = remedies[category];
          if (value is List) {
            remedyMap[category] = value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
          } else {
            remedyMap[category] = const [];
          }
        }

        _remediesByNormalizedClass[normalizedClass] = remedyMap;
        _displayClassByNormalizedClass[normalizedClass] = diseaseClass;
      }
    } catch (e) {
      debugPrint('Remedy JSON load error: $e');
      if (mounted) {
        setState(() {
          _error = 'Remedy file load failed: $e';
        });
      }
    }
  }

  String _normalizeDiseaseName(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Set<String> _tokensOf(String value) {
    return _normalizeDiseaseName(value).split(' ').where((e) => e.isNotEmpty).toSet();
  }

  MapEntry<String, Map<String, List<String>>>? _matchRemedies(String predictedClass) {
    if (_remediesByNormalizedClass.isEmpty) return null;

    final normalizedPrediction = _normalizeDiseaseName(predictedClass);
    final exact = _remediesByNormalizedClass[normalizedPrediction];
    if (exact != null) {
      return MapEntry(
        _displayClassByNormalizedClass[normalizedPrediction] ?? predictedClass,
        exact,
      );
    }

    final predictionTokens = _tokensOf(predictedClass);
    double bestScore = 0;
    String? bestKey;

    for (final entry in _remediesByNormalizedClass.entries) {
      final candidateTokens = _tokensOf(entry.key);
      if (candidateTokens.isEmpty) continue;
      final overlap = predictionTokens.intersection(candidateTokens).length;
      var score = overlap / candidateTokens.length;
      if (normalizedPrediction.contains(entry.key) || entry.key.contains(normalizedPrediction)) {
        score += 0.35;
      }
      if (score > bestScore) {
        bestScore = score;
        bestKey = entry.key;
      }
    }

    if (bestKey != null && bestScore >= 0.45) {
      return MapEntry(
        _displayClassByNormalizedClass[bestKey] ?? predictedClass,
        _remediesByNormalizedClass[bestKey]!,
      );
    }

    return null;
  }

  Future<void> _loadModel() async {
    setState(() => _loadingModel = true);
    try {
      _interpreter = await Interpreter.fromAsset(_modelAsset);
      try {
        final raw = await rootBundle.loadString(_labelsAsset);
        _labels = raw.split('\n').where((e) => e.trim().isNotEmpty).toList();
        if (_labels.isEmpty) _labels = _defaultLabels;
      } catch (_) {
        _labels = _defaultLabels;
      }
      _error = null;
    } catch (e) {
      debugPrint('Model load error: $e');
      final windowsHint = Platform.isWindows
          ? '\nEnsure libtensorflowlite_c-win.dll is present in '
              '${Directory(Platform.resolvedExecutable).parent.path}\\blobs.'
          : '';
      _error = 'Model load failed: $e$windowsHint';
    } finally {
      if (mounted) setState(() => _loadingModel = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() {
      _imageFile = File(picked.path);
      _predictedLabel = null;
      _confidence = null;
      _matchedRemedyClass = null;
      _matchedRemedies = null;
    });
  }

  Future<void> _captureImage() async {
    final picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;
    setState(() {
      _imageFile = File(picked.path);
      _predictedLabel = null;
      _confidence = null;
      _matchedRemedyClass = null;
      _matchedRemedies = null;
    });
  }

  Future<void> _runInference() async {
    if (_imageFile == null || _interpreter == null) return;
    setState(() => _running = true);
    try {
      final bytes = await _imageFile!.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) throw Exception('Could not decode image');

      const inputSize = 224;
      final resized = img.copyResize(decoded, width: inputSize, height: inputSize);

      final imageAsList = List.generate(inputSize, (y) {
        return List.generate(inputSize, (x) {
          final p = resized.getPixel(x, y);
          final r = p.r / 255.0;
          final g = p.g / 255.0;
          final b = p.b / 255.0;
          return [r, g, b];
        });
      });

      final input = [imageAsList];
      final outputClasses = _labels.isNotEmpty
          ? _labels.length
          : _interpreter!.getOutputTensor(0).shape.last;
      final output = List.generate(1, (_) => List<double>.filled(outputClasses, 0));
      _interpreter!.run(input, output);

      final scores = output.first;
      debugPrint('[Disease] Raw scores (first 5): ${scores.take(5).toList()}');
      debugPrint('[Disease] Labels count: ${_labels.length}');

      // Apply softmax normalization to convert logits to probabilities
      final maxScore = scores.reduce((a, b) => a > b ? a : b);
      final normalizedScores = scores.map((s) => s - maxScore).toList();
      final expScores = normalizedScores.map((s) => (s as num).exp().toDouble()).toList();
      final sumExp = expScores.reduce((a, b) => a + b);
      final softmaxScores = expScores.map((e) => e / sumExp).toList();

      int maxIdx = 0;
      double confidenceScore = softmaxScores[0];
      for (int i = 1; i < softmaxScores.length; i++) {
        if (softmaxScores[i] > confidenceScore) {
          confidenceScore = softmaxScores[i];
          maxIdx = i;
        }
      }

      // Get top 5 predictions
      final predictions = <MapEntry<String, double>>[];
      for (int i = 0; i < softmaxScores.length; i++) {
        predictions.add(MapEntry(
          _labels.isNotEmpty && i < _labels.length ? _labels[i] : 'Class $i',
          softmaxScores[i],
        ));
      }
      predictions.sort((a, b) => b.value.compareTo(a.value));
      final top5 = predictions.take(5).toList();
      debugPrint('[Disease] Top 5 predictions:');
      for (var p in top5) {
        debugPrint('  ${p.key}: ${(p.value * 100).toStringAsFixed(2)}%');
      }

      final predictedLabel = _labels.isNotEmpty && maxIdx < _labels.length ? _labels[maxIdx] : 'Class $maxIdx';
      final matched = _matchRemedies(predictedLabel);
      setState(() {
        _predictedLabel = predictedLabel;
        _confidence = confidenceScore;
        _topPredictions = top5;
        _matchedRemedyClass = matched?.key;
        _matchedRemedies = matched?.value;
        _error = null;
      });
    } catch (e) {
      debugPrint('Inference error: $e');
      _error = 'Inference failed: $e';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Inference failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crop Disease Assistant')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                  ],
                  const Text('Step 1: Upload leaf image'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: _imageFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(_imageFile!, fit: BoxFit.cover, width: double.infinity),
                            )
                          : const Center(child: Text('Tap to select image')),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _captureImage,
                          icon: const Icon(Icons.camera_alt_rounded),
                          label: const Text('Camera'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.photo_library_rounded),
                          label: const Text('Gallery'),
                        ),
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Step 2: Run detection'),
                  const SizedBox(height: 8),
                  if (_loadingModel)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('Loading model...'),
                    ),
                  ElevatedButton(
                    onPressed: (_running || _loadingModel) ? null : _runInference,
                    child: (_running || _loadingModel)
                        ? const CircularProgressIndicator.adaptive()
                        : const Text('Analyze image'),
                  ),
                  if (_predictedLabel != null) ...[
                    const SizedBox(height: 16),
                    Text('Prediction: $_predictedLabel', style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (_confidence != null) Text('Confidence: ${(_confidence! * 100).toStringAsFixed(1)}%'),
                    if (_topPredictions != null && _topPredictions!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('Top 5 predictions:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      const SizedBox(height: 6),
                      ..._topPredictions!.map((pred) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(pred.key, style: const TextStyle(fontSize: 11)),
                              flex: 2,
                            ),
                            Text('${(pred.value * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      )),
                    ],
                    if (_matchedRemedies == null) ...[
                      const SizedBox(height: 8),
                      const Text('No matching remedy found in remedieses.json for this disease.'),
                    ],
                  ],
                ],
              ),
            ),
          ),
          if (_matchedRemedies != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Recommended remedies (5 types)', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    if (_matchedRemedyClass != null)
                      Text('Matched disease: $_matchedRemedyClass', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ..._remedyCategories.map((category) {
                      final values = _matchedRemedies![category] ?? const [];
                      final title = '${category[0].toUpperCase()}${category.substring(1)}';
                      final text = values.isEmpty ? 'Not available' : values.join(', ');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('$title: $text'),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
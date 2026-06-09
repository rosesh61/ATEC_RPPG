import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import '../models/rppg_signal.dart';

class RppgService {
  late OnnxRuntime _ort;
  OrtSession? _modelSession;
  OrtSession? _getHrSession;
  OrtSession? _welchSession;
  bool _isInitialized = false;

  // Model state for stateful RNN
  final Map<String, OrtValue> _modelState = {};
  double? _lastTimestamp;

  final List<List<double>> _signalBuffer = [];
  static const int _bufferSize = 900; // 30 seconds at 30 fps
  static const int _windowSize =
      300; // 10 seconds for processing (required by Welch model — fixed size)

  int _frameCount = 0; // 프레임 카운터
  double? _lastCalculatedHr; // 마지막으로 계산된 HR
  static const int _hrCalculationInterval = 30; // 30 프레임마다 (약 1초) HR 계산
  bool _firstHrCalculated = false; // 첫 HR 계산 여부

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize ONNX Runtime
      _ort = OnnxRuntime();

      // Load ONNX models from assets
      _modelSession = await _ort.createSessionFromAsset(
        'assets/models/model.onnx',
      );
      _getHrSession = await _ort.createSessionFromAsset(
        'assets/models/get_hr.onnx',
      );
      _welchSession = await _ort.createSessionFromAsset(
        'assets/models/welch_psd.onnx',
      );

      // Log model input/output names
      print('Model inputs: ${_modelSession?.inputNames}');
      print('Model outputs: ${_modelSession?.outputNames}');
      print('Welch inputs: ${_welchSession?.inputNames}');
      print('Welch outputs: ${_welchSession?.outputNames}');
      print('GetHR inputs: ${_getHrSession?.inputNames}');
      print('GetHR outputs: ${_getHrSession?.outputNames}');

      // Load initial state from state.json
      await _loadInitialState();

      _isInitialized = true;
      print('rPPG models loaded successfully');
    } catch (e) {
      print('Error loading rPPG models: $e');
      rethrow;
    }
  }

  Future<void> _loadInitialState() async {
    try {
      final stateJson = await rootBundle.loadString('assets/models/state.json');
      final stateData = json.decode(stateJson) as Map<String, dynamic>;

      for (final entry in stateData.entries) {
        final key = entry.key;
        final value = entry.value;

        // Convert nested list to flat Float32List and determine shape
        final (flatList, shape) = _flattenNestedList(value);
        final tensor = await OrtValue.fromList(flatList, shape);
        _modelState[key] = tensor;
      }

      print('Initial state loaded with ${_modelState.length} tensors');
    } catch (e) {
      print('Error loading initial state: $e');
      rethrow;
    }
  }

  (List<double>, List<int>) _flattenNestedList(dynamic data) {
    // Recursively flatten nested list and calculate shape
    List<int> shape = [];
    dynamic current = data;

    while (current is List && current.isNotEmpty) {
      shape.add(current.length);
      current = current[0];
    }

    // Flatten the list
    List<double> flatList = [];
    void flatten(dynamic item) {
      if (item is List) {
        for (var element in item) {
          flatten(element);
        }
      } else {
        flatList.add((item as num).toDouble());
      }
    }

    flatten(data);
    return (flatList, shape);
  }

  Future<RppgSignal?> processFrame(
    img.Image faceImage,
    double timestamp,
  ) async {
    if (!_isInitialized || _modelSession == null) {
      throw Exception('rPPG service not initialized');
    }

    try {
      _frameCount++; // 매 프레임마다 카운트 증가
      // Resize face to 36x36
      final resized = img.copyResize(faceImage, width: 36, height: 36);

      // Convert to normalized float array [1, 1, 36, 36, 3] format
      final input = _imageToFloat32ListHWC(resized);

      // Create input tensor [1, 1, 36, 36, 3] (batch, time, height, width, channels)
      final inputTensor = await OrtValue.fromList(input.toList(), [
        1,
        1,
        36,
        36,
        3,
      ]);

      // Build feeds dictionary with input, state, and delta time
      final feeds = <String, OrtValue>{};
      final inputNames = _modelSession!.inputNames;

      // First input is the image
      feeds[inputNames[0]] = inputTensor;

      // Add all state tensors (inputs 1 to 36)
      for (int i = 1; i < inputNames.length - 1; i++) {
        final stateName = inputNames[i];
        if (_modelState.containsKey(stateName)) {
          feeds[stateName] = _modelState[stateName]!;
        }
      }

      // Last input is delta time
      final dt = _lastTimestamp != null ? timestamp - _lastTimestamp! : 0.0;
      _lastTimestamp = timestamp;
      final dtTensor = await OrtValue.fromList([dt], []);
      feeds[inputNames.last] = dtTensor;

      // Run inference
      final outputs = await _modelSession!.run(feeds);

      // Update state for next frame (outputs 1 to N-1 become next state)
      final outputNames = _modelSession!.outputNames;
      for (int i = 1; i < outputNames.length; i++) {
        final outputName = outputNames[i];
        final inputName = inputNames[i];
        if (outputs.containsKey(outputName)) {
          _modelState[inputName] = outputs[outputName]!;
        }
      }

      // Extract signal from first output
      final outputValue = outputs[outputNames[0]];
      if (outputValue == null) {
        print('⚠ Model output is null');
        return null;
      }

      final outputList = await outputValue.asList();

      // Extract signal value - may be nested list
      double signalValue;
      if (outputList is List && outputList.isNotEmpty) {
        var value = outputList[0];
        // Flatten nested lists
        while (value is List && value.isNotEmpty) {
          value = value[0];
        }
        signalValue = (value as num).toDouble();
      } else {
        print('Unexpected output format');
        return null;
      }

      // Add to buffer as single value
      _signalBuffer.add([signalValue]);
      if (_signalBuffer.length > _bufferSize) {
        _signalBuffer.removeAt(0);
      }

      // Calculate heart rate if we have enough data
      double? heartRate;
      bool isNewHr = false;
      if (_signalBuffer.length >= _windowSize) {
        // 버퍼가 처음 가득 찼을 때 즉시 계산 (fps 관계없이 보장)
        final shouldCalculate = !_firstHrCalculated ||
            (_frameCount % _hrCalculationInterval == 0);
        if (shouldCalculate) {
          _lastCalculatedHr = await _calculateHeartRate();
          if (_lastCalculatedHr != null) {
            isNewHr = true;
            _firstHrCalculated = true;
          } else {
            print(
              '⚠ HR calculation returned null (buffer size: ${_signalBuffer.length})',
            );
          }
        }
        // 계산 주기가 아닐 때는 마지막으로 성공한 HR 값을 사용
        heartRate = _lastCalculatedHr;
      }

      return RppgSignal(
        signal: [signalValue],
        timestamp: timestamp,
        heartRate: heartRate,
        isNewHrCalculation: isNewHr,
      );
    } catch (e) {
      print('Error processing frame: $e');
      return null;
    }
  }

  Future<double?> _calculateHeartRate() async {
    if (_welchSession == null || _getHrSession == null) {
      print('⚠ HR calc failed: Welch or GetHR session not initialized');
      return null;
    }

    try {
      // Get last _windowSize signals
      final recentSignals = _signalBuffer.sublist(
        _signalBuffer.length - _windowSize,
      );

      // Flatten signals for Welch PSD
      final flatSignals = recentSignals.expand((s) => s).toList();

      // Apply Welch periodogram with correct shape [1, 1, length]
      final welchInput = await OrtValue.fromList(flatSignals, [
        1,
        1,
        flatSignals.length,
      ]);

      final welchOutputs = await _welchSession!.run({'input': welchInput});

      // Welch outputs both freqs and psd
      if (welchOutputs.isEmpty || welchOutputs.length < 2) {
        print(
          '⚠ HR calc failed: Welch outputs invalid (count: ${welchOutputs.length})',
        );
        return null;
      }

      // Get the frequency and PSD outputs by key name (not index!)
      final outputKeys = welchOutputs.keys.toList();
      print('Welch output keys: $outputKeys');

      final freqsValue = welchOutputs['freqs'];
      final psdValue = welchOutputs['psd'];

      if (freqsValue == null || psdValue == null) {
        print(
          '⚠ HR calc failed: Welch freqs or psd is null (keys: $outputKeys)',
        );
        return null;
      }

      // Log shapes for debugging
      var freqsList = await freqsValue.asList();
      var psdList = await psdValue.asList();

      print(
        'Welch raw output - freqs: ${freqsList.length} items (type: ${freqsList.runtimeType})',
      );
      print(
        'Welch raw output - psd: ${psdList.length} items (type: ${psdList.runtimeType})',
      );

      // Recursively flatten nested lists
      List<double> flattenList(dynamic data) {
        if (data is List) {
          return data.expand((item) => flattenList(item)).toList();
        } else {
          return [(data as num).toDouble()];
        }
      }

      final freqsFlat = flattenList(freqsList);
      final psdFlat = flattenList(psdList);

      print(
        'Welch flattened - freqs: ${freqsFlat.length} items, psd: ${psdFlat.length} items',
      );

      // GetHR expects different ranks for freqs and psd!
      // freqs: 1D [length]
      // psd: 2D [1, length]
      final freqsInput = await OrtValue.fromList(freqsFlat, [freqsFlat.length]);
      final psdInput = await OrtValue.fromList(psdFlat, [1, psdFlat.length]);

      // Get heart rate from freqs and psd
      final hrOutputs = await _getHrSession!.run({
        'freqs': freqsInput,
        'psd': psdInput,
      });

      if (hrOutputs.isEmpty) {
        print('⚠ HR calc failed: GetHR outputs empty');
        return null;
      }

      final hrValue = hrOutputs.values.first;
      if (hrValue == null) {
        print('⚠ HR calc failed: HR value is null');
        return null;
      }

      final hrList = await hrValue.asList();
      final heartRate = hrList[0] as double;

      print(
        '✓ HR calculated successfully: ${heartRate.toStringAsFixed(1)} BPM',
      );
      return heartRate;
    } catch (e) {
      print('⚠ HR calc exception: $e');
      return null;
    }
  }

  Float32List _imageToFloat32ListHWC(img.Image image) {
    final pixels = Float32List(36 * 36 * 3);
    int idx = 0;

    // Convert to HWC format (height, width, channels) as per original implementation
    for (int y = 0; y < 36; y++) {
      for (int x = 0; x < 36; x++) {
        final pixel = image.getPixel(x, y);
        // RGB channels
        pixels[idx++] = pixel.r / 255.0;
        pixels[idx++] = pixel.g / 255.0;
        pixels[idx++] = pixel.b / 255.0;
      }
    }

    return pixels;
  }

  void reset() {
    _signalBuffer.clear();
    _lastTimestamp = null;

    _frameCount = 0;
    _lastCalculatedHr = null;
    _firstHrCalculated = false;

    // Reload initial state
    if (_isInitialized) {
      _loadInitialState();
    }
  }

  int get bufferLength => _signalBuffer.length;
  bool get hasEnoughData => _signalBuffer.length >= _windowSize;

  /// 피크 검출용 신호 버퍼 (1차원 평탄화)
  List<double> get signalValues =>
      _signalBuffer.map((s) => s.first).toList();

  void dispose() {
    // flutter_onnxruntime handles memory management automatically
    _modelSession = null;
    _getHrSession = null;
    _welchSession = null;
    _signalBuffer.clear();
    _modelState.clear();
    _lastTimestamp = null;
    _isInitialized = false;
  }
}

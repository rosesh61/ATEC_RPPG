import 'dart:math';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;
import '../utils/camera_image_converter.dart';

/// YuNet + SFace ONNX 파이프라인.
/// 웹 키오스크(Python/OpenCV)와 완전히 동일한 전처리:
///   YuNet 얼굴 감지 → 5개 랜드마크 기반 alignCrop → SFace 128차원 임베딩
class FaceRecognitionService {
  static final FaceRecognitionService instance =
      FaceRecognitionService._internal();
  FaceRecognitionService._internal();

  OrtSession? _yunetSession;
  OrtSession? _sfaceSession;
  bool _isInitialized = false;

  static const int _sfaceW = 112;
  static const int _sfaceH = 112;

  // YuNet 입력 크기 (모델 고정값)
  static const int _yunetW = 640;
  static const int _yunetH = 640;

  // OpenCV FaceRecognizerSF::alignCrop 기준 mean face landmarks (112×112 좌표)
  // 출처: opencv/modules/objdetect/src/face_recognize.cpp
  static const List<List<double>> _meanFacePts = [
    [38.2946, 51.6963], // right eye
    [73.5318, 51.5014], // left eye
    [56.0252, 71.7366], // nose tip
    [41.5493, 92.3655], // right mouth corner
    [70.7299, 92.2041], // left mouth corner
  ];

  static const double defaultThreshold = 0.30;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final ort = OnnxRuntime();
      _yunetSession = await ort.createSessionFromAsset(
        'assets/models/face_detection_yunet_2023mar.onnx',
      );
      _sfaceSession = await ort.createSessionFromAsset(
        'assets/models/face_recognition_sface_2021dec.onnx',
      );
      _isInitialized = true;
      print('[FaceRecognitionService] YuNet + SFace 초기화 완료');
    } catch (e) {
      print('[FaceRecognitionService] 초기화 실패: $e');
      rethrow;
    }
  }

  bool get isInitialized => _isInitialized;

  /// CameraImage(YUV420)에서 128차원 임베딩 추출 (실시간 로그인용)
  Future<List<double>?> extractDescriptorFromCameraImage(
    CameraImage cameraImage,
    dynamic faceRect, // 호환성 유지용 파라미터 (미사용)
    int sensorOrientation,
    bool isFrontCamera,
  ) async {
    if (!_isInitialized) return null;
    try {
      final rgbImage = CameraImageConverter.toRgb(cameraImage);
      if (rgbImage == null) return null;
      final oriented = _rotateBySensor(rgbImage, sensorOrientation, isFrontCamera);
      return await _detectAndEmbed(oriented);
    } catch (e) {
      print('[FaceRecognitionService] CameraImage 임베딩 실패: $e');
      return null;
    }
  }

  /// JPEG bytes에서 128차원 임베딩 추출 (등록 시 takePicture() 이미지)
  Future<List<double>?> extractDescriptorFromJpeg(Uint8List jpegBytes) async {
    print('[FaceRecognitionService] extractDescriptorFromJpeg 호출, isInitialized=$_isInitialized, bytes=${jpegBytes.length}');
    if (!_isInitialized) {
      print('[FaceRecognitionService] 초기화 안 됨!');
      return null;
    }
    try {
      final decoded = img.decodeImage(jpegBytes);
      print('[FaceRecognitionService] 이미지 디코드: ${decoded?.width}x${decoded?.height}');
      if (decoded == null) return null;
      return await _detectAndEmbed(decoded);
    } catch (e, st) {
      print('[FaceRecognitionService] JPEG 임베딩 실패: $e\n$st');
      return null;
    }
  }

  /// 두 128차원 벡터 간 코사인 유사도
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    double dot = 0.0, normA = 0.0, normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denom = sqrt(normA) * sqrt(normB);
    return denom == 0 ? 0.0 : dot / denom;
  }

  // ── 내부: YuNet 감지 → alignCrop → SFace 임베딩 ──────────────

  Future<List<double>?> _detectAndEmbed(img.Image image) async {
    print('[FaceRecognitionService] _detectAndEmbed 시작: ${image.width}x${image.height}');

    // 1. YuNet 입력: 640×640 BGR Float32 NCHW
    final resized = img.copyResize(image,
        width: _yunetW, height: _yunetH,
        interpolation: img.Interpolation.linear);

    final scaleX = image.width / _yunetW.toDouble();
    final scaleY = image.height / _yunetH.toDouble();

    print('[FaceRecognitionService] YuNet 텐서 생성 중...');
    // YuNet은 BGR 입력 (OpenCV 기준)
    final yunetTensor = await OrtValue.fromList(
      _imageToNchwBgr(resized, _yunetW, _yunetH).toList(),
      [1, 3, _yunetH, _yunetW],
    );

    // 2. YuNet 실행
    final yunetInputName = _yunetSession!.inputNames.isNotEmpty
        ? _yunetSession!.inputNames[0]
        : 'input';
    print('[FaceRecognitionService] YuNet 실행 중 (inputName=$yunetInputName)...');
    final yunetOut = await _yunetSession!.run({yunetInputName: yunetTensor});
    print('[FaceRecognitionService] YuNet 출력 키: ${yunetOut.keys.toList()}');

    // 3. YuNet 출력 파싱 → 가장 confidence 높은 얼굴 선택
    final face = await _decodeYunetOutputs(yunetOut, scaleX, scaleY);
    if (face == null) {
      print('[FaceRecognitionService] 얼굴 미감지');
      return null;
    }
    print('[FaceRecognitionService] 얼굴 감지 score=${face.score.toStringAsFixed(3)}');

    // 4. alignCrop: 5개 랜드마크 → similarity transform → 112×112
    final aligned = _alignCrop(image, face);
    if (aligned == null) return null;

    // 5. SFace 임베딩
    return await _runSface(aligned);
  }

  // ── YuNet 출력 디코드 ────────────────────────────────────────────

  /// 12개 출력 텐서를 FCOS 방식으로 디코드 후 가장 높은 score 얼굴 반환
  Future<_YuNetFace?> _decodeYunetOutputs(
      Map<String, OrtValue> outputs, double scaleX, double scaleY) async {
    // 출력 이름 순서: cls_8,cls_16,cls_32, obj_8,..., bbox_8,..., kps_8,...
    // flutter_onnxruntime은 순서대로 반환
    final keys = outputs.keys.toList();

    // 이름으로 각 텐서 찾기
    Future<List<List<double>>> getTensor(String prefix) async {
      for (final key in keys) {
        if (key.startsWith(prefix)) {
          final raw = await outputs[key]!.asList();
          return _flatten3d(raw);
        }
      }
      return [];
    }

    // stride별로 처리
    _YuNetFace? best;
    double globalMaxScore = 0.0;

    for (final entry in [
      {'stride': 8, 'cls': 'cls_8', 'obj': 'obj_8', 'bbox': 'bbox_8', 'kps': 'kps_8'},
      {'stride': 16, 'cls': 'cls_16', 'obj': 'obj_16', 'bbox': 'bbox_16', 'kps': 'kps_16'},
      {'stride': 32, 'cls': 'cls_32', 'obj': 'obj_32', 'bbox': 'bbox_32', 'kps': 'kps_32'},
    ]) {
      final stride = entry['stride'] as int;
      final clsKey = entry['cls'] as String;
      final objKey = entry['obj'] as String;
      final bboxKey = entry['bbox'] as String;
      final kpsKey = entry['kps'] as String;

      if (!outputs.containsKey(clsKey)) continue;

      final clsRaw  = await outputs[clsKey]!.asList();
      final objRaw  = await outputs[objKey]!.asList();
      final bboxRaw = await outputs[bboxKey]!.asList();
      final kpsRaw  = await outputs[kpsKey]!.asList();

      // 첫 stride에서만 구조 출력
      if (stride == 8) {
        print('[YuNet] cls_8 raw type=${clsRaw.runtimeType}, len=${(clsRaw as List).length}');
        if ((clsRaw as List).isNotEmpty) {
          final first = (clsRaw as List).first;
          print('[YuNet] cls_8[0] type=${first.runtimeType}, val=$first');
          if (first is List && first.isNotEmpty) {
            print('[YuNet] cls_8[0][0] type=${first.first.runtimeType}, val=${first.first}');
          }
        }
      }

      final clsFlat  = _flattenNd(clsRaw);   // [N]
      final objFlat  = _flattenNd(objRaw);   // [N]
      final bboxFlat = _flattenNd(bboxRaw); // [N×4]
      final kpsFlat  = _flattenNd(kpsRaw); // [N×10]

      final fh = _yunetH ~/ stride;
      final fw = _yunetW ~/ stride;

      print('[YuNet] stride=$stride clsFlat.length=${clsFlat.length} (expected ${fh * fw})');

      double strideMax = 0.0;
      for (int i = 0; i < clsFlat.length; i++) {
        final score = _sigmoid(clsFlat[i]) * _sigmoid(objFlat[i]);
        if (score > strideMax) strideMax = score;
        if (score > globalMaxScore) globalMaxScore = score;
        if (score < 0.5) continue;

        // anchor center (FCOS: anchor at cell center)
        final row = i ~/ fw;
        final col = i % fw;
        final anchorCx = (col + 0.5) * stride;
        final anchorCy = (row + 0.5) * stride;

        // bbox decode: FCOS 스타일 [l, t, r, b] distances
        final l = bboxFlat[i * 4 + 0] * stride;
        final t = bboxFlat[i * 4 + 1] * stride;
        final r = bboxFlat[i * 4 + 2] * stride;
        final b = bboxFlat[i * 4 + 3] * stride;

        final x = (anchorCx - l) * scaleX;
        final y = (anchorCy - t) * scaleY;
        final w = (l + r) * scaleX;
        final h = (t + b) * scaleY;

        // landmark decode
        final landmarks = List.generate(5, (k) {
          final kx = (anchorCx + kpsFlat[i * 10 + k * 2]     * stride) * scaleX;
          final ky = (anchorCy + kpsFlat[i * 10 + k * 2 + 1] * stride) * scaleY;
          return [kx, ky];
        });

        if (best == null || score > best.score) {
          best = _YuNetFace(x: x, y: y, w: w, h: h,
              landmarks: landmarks, score: score);
        }
      }
      print('[YuNet] stride=$stride maxScore=${strideMax.toStringAsFixed(3)}');
    }

    print('[YuNet] 전체 최고 score=${globalMaxScore.toStringAsFixed(3)} (threshold=0.6)');
    return best;
  }

  // ── alignCrop (OpenCV FaceRecognizerSF::alignCrop 재현) ─────────

  img.Image? _alignCrop(img.Image src, _YuNetFace face) {
    final srcPts = face.landmarks; // 5개 [x, y]
    final dstPts = _meanFacePts;  // 5개 [x, y] (112×112 기준)

    final m = _estimateSimilarityTransform(srcPts, dstPts);
    if (m == null) return null;

    return _warpAffine(src, m, _sfaceW, _sfaceH);
  }

  /// 5쌍 대응점 → similarity transform 2×3 행렬
  /// [a, -b, tx]   (scale·rotation + translation)
  /// [b,  a, ty]
  List<List<double>>? _estimateSimilarityTransform(
      List<List<double>> src, List<List<double>> dst) {
    const n = 5;
    // 정규방정식: A(2n×4) x = b(2n)
    // [x, -y, 1, 0] [a ]   [X]
    // [y,  x, 0, 1] [b ] = [Y]
    //               [tx]
    //               [ty]
    final A = List.generate(2 * n, (_) => List<double>.filled(4, 0.0));
    final bv = List<double>.filled(2 * n, 0.0);

    for (int i = 0; i < n; i++) {
      final x = src[i][0], y = src[i][1];
      final X = dst[i][0], Y = dst[i][1];
      A[2 * i]     = [x, -y, 1.0, 0.0];
      A[2 * i + 1] = [y,  x, 0.0, 1.0];
      bv[2 * i]    = X;
      bv[2 * i + 1] = Y;
    }

    // AᵀA (4×4), Aᵀb (4)
    final At = _transpose(A, 2 * n, 4);
    final AtA = _matMul(At, A, 4, 2 * n, 4);
    final Atb = _matVec(At, bv, 4, 2 * n);

    final params = _solveGaussian(AtA, Atb, 4);
    if (params == null) return null;

    final a = params[0], b = params[1], tx = params[2], ty = params[3];
    return [
      [a, -b, tx],
      [b,  a, ty],
    ];
  }

  /// Affine warp: inverse mapping + bilinear interpolation
  img.Image _warpAffine(
      img.Image src, List<List<double>> m, int dstW, int dstH) {
    final dst = img.Image(width: dstW, height: dstH);

    final a = m[0][0], b = m[0][1], tx = m[0][2];
    final c = m[1][0], d = m[1][1], ty = m[1][2];

    final det = a * d - b * c;
    if (det.abs() < 1e-10) return dst;

    // 역행렬
    final iA =  d / det, iB = -b / det;
    final iC = -c / det, iD =  a / det;
    final iTx = (b * ty - d * tx) / det;
    final iTy = (c * tx - a * ty) / det;

    for (int dy = 0; dy < dstH; dy++) {
      for (int dx = 0; dx < dstW; dx++) {
        final sx = iA * dx + iB * dy + iTx;
        final sy = iC * dx + iD * dy + iTy;
        final px = _bilinear(src, sx, sy);
        dst.setPixelRgb(dx, dy, px[0], px[1], px[2]);
      }
    }
    return dst;
  }

  List<int> _bilinear(img.Image src, double x, double y) {
    final x0 = x.floor().clamp(0, src.width - 1);
    final y0 = y.floor().clamp(0, src.height - 1);
    final x1 = (x0 + 1).clamp(0, src.width - 1);
    final y1 = (y0 + 1).clamp(0, src.height - 1);
    final fx = x - x0, fy = y - y0;

    final p00 = src.getPixel(x0, y0);
    final p10 = src.getPixel(x1, y0);
    final p01 = src.getPixel(x0, y1);
    final p11 = src.getPixel(x1, y1);

    int lerp(num a, num b, num c, num d) =>
        ((a * (1 - fx) + b * fx) * (1 - fy) +
            (c * (1 - fx) + d * fx) * fy)
            .round()
            .clamp(0, 255);

    return [
      lerp(p00.r, p10.r, p01.r, p11.r),
      lerp(p00.g, p10.g, p01.g, p11.g),
      lerp(p00.b, p10.b, p01.b, p11.b),
    ];
  }

  // ── SFace 실행 ──────────────────────────────────────────────────

  Future<List<double>?> _runSface(img.Image faceImage) async {
    final session = _sfaceSession;
    if (session == null) return null;

    final resized = img.copyResize(faceImage,
        width: _sfaceW, height: _sfaceH,
        interpolation: img.Interpolation.linear);

    final ortTensor = await OrtValue.fromList(
      _imageToNchwBgr(resized, _sfaceW, _sfaceH).toList(),
      [1, 3, _sfaceH, _sfaceW],
    );

    final inputName = session.inputNames.isNotEmpty ? session.inputNames[0] : 'data';
    final outputs = await session.run({inputName: ortTensor});
    if (outputs.isEmpty) return null;

    final raw = await outputs.values.first.asList();
    List<dynamic> flat = raw;
    while (flat.isNotEmpty && flat.first is List) {
      flat = flat.first as List<dynamic>;
    }
    return flat.map((v) => (v as num).toDouble()).toList();
  }

  // ── 이미지 변환 헬퍼 ────────────────────────────────────────────

  Float32List _imageToNchwBgr(img.Image image, int w, int h) {
    final tensor = Float32List(w * h * 3);
    int idx = 0;
    for (int c = 0; c < 3; c++) {
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final pixel = image.getPixel(x, y);
          // c=0→B, c=1→G, c=2→R
          tensor[idx++] = c == 0
              ? pixel.b.toDouble()
              : c == 1
                  ? pixel.g.toDouble()
                  : pixel.r.toDouble();
        }
      }
    }
    return tensor;
  }

  img.Image _rotateBySensor(img.Image src, int sensorOrientation, bool isFrontCamera) {
    if (isFrontCamera) {
      final flipped = img.flipHorizontal(src);
      if (sensorOrientation == 270) return img.copyRotate(flipped, angle: 90);
      if (sensorOrientation == 90)  return img.copyRotate(flipped, angle: 270);
      return flipped;
    } else {
      if (sensorOrientation == 90)  return img.copyRotate(src, angle: 90);
      if (sensorOrientation == 270) return img.copyRotate(src, angle: 270);
      if (sensorOrientation == 180) return img.copyRotate(src, angle: 180);
      return src;
    }
  }

  void dispose() {
    _yunetSession?.close();
    _sfaceSession?.close();
    _yunetSession = null;
    _sfaceSession = null;
    _isInitialized = false;
  }

  // ── 선형대수 헬퍼 ────────────────────────────────────────────────

  double _sigmoid(double x) => 1.0 / (1.0 + exp(-x.clamp(-88.0, 88.0)));

  List<List<double>> _transpose(List<List<double>> m, int rows, int cols) =>
      List.generate(cols, (j) => List.generate(rows, (i) => m[i][j]));

  List<List<double>> _matMul(
      List<List<double>> a, List<List<double>> b, int r1, int c, int c2) {
    final res = List.generate(r1, (_) => List<double>.filled(c2, 0.0));
    for (int i = 0; i < r1; i++)
      for (int j = 0; j < c2; j++)
        for (int k = 0; k < c; k++) res[i][j] += a[i][k] * b[k][j];
    return res;
  }

  List<double> _matVec(List<List<double>> a, List<double> v, int rows, int cols) {
    final res = List<double>.filled(rows, 0.0);
    for (int i = 0; i < rows; i++)
      for (int j = 0; j < cols; j++) res[i] += a[i][j] * v[j];
    return res;
  }

  /// n×n 선형계 가우스 소거
  List<double>? _solveGaussian(List<List<double>> A, List<double> b, int n) {
    final m = List.generate(n, (i) => [...A[i], b[i]]);
    for (int col = 0; col < n; col++) {
      int pivot = col;
      for (int row = col + 1; row < n; row++)
        if (m[row][col].abs() > m[pivot][col].abs()) pivot = row;
      final tmp = m[col]; m[col] = m[pivot]; m[pivot] = tmp;
      if (m[col][col].abs() < 1e-12) return null;
      for (int row = 0; row < n; row++) {
        if (row == col) continue;
        final f = m[row][col] / m[col][col];
        for (int k = col; k <= n; k++) m[row][k] -= f * m[col][k];
      }
    }
    return List.generate(n, (i) => m[i][n] / m[i][i]);
  }

  // ── 텐서 flatten 헬퍼 ────────────────────────────────────────────

  /// [1, N, 1] → [N] (cls/obj)
  List<double> _flatten2d(dynamic raw) {
    List<dynamic> r = raw as List<dynamic>;
    while (r.isNotEmpty && r.first is List) r = r.first as List<dynamic>;
    // r이 [N] 이어야 하지만 [N,1]일 수도 있음
    if (r.isNotEmpty && r.first is List) {
      return (r as List<dynamic>).map((e) {
        final row = e as List<dynamic>;
        return (row.first as num).toDouble();
      }).toList();
    }
    return r.map((e) => (e as num).toDouble()).toList();
  }

  /// [1, N, 4] → flat index: row[i*4+j]
  List<double> _flatten2d4(dynamic raw) => _flattenNd(raw);

  /// [1, N, 10] → flat index: row[i*10+j]
  List<double> _flatten2d10(dynamic raw) => _flattenNd(raw);

  List<double> _flattenNd(dynamic raw) {
    final result = <double>[];
    void recurse(dynamic val) {
      if (val is List) {
        for (final v in val) recurse(v);
      } else {
        result.add((val as num).toDouble());
      }
    }
    recurse(raw);
    return result;
  }

  List<List<double>> _flatten3d(dynamic raw) {
    // [1, N, K] → List<List<double>> [N][K]
    List<dynamic> r = raw as List<dynamic>;
    while (r.isNotEmpty && r.first is List && (r.first as List).isNotEmpty &&
        (r.first as List).first is List) {
      r = r.first as List<dynamic>;
    }
    return r
        .map((e) => (e as List<dynamic>).map((v) => (v as num).toDouble()).toList())
        .toList();
  }
}

// ── 데이터 클래스 ───────────────────────────────────────────────────

class _YuNetFace {
  final double x, y, w, h;
  final List<List<double>> landmarks; // 5×2: [re, le, nose, rm, lm]
  final double score;

  const _YuNetFace({
    required this.x, required this.y,
    required this.w, required this.h,
    required this.landmarks,
    required this.score,
  });
}

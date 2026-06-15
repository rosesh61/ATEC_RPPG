import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

/// CameraImage → NV21 / RGB 변환 유틸.
///
/// 기기 모델별 분기 대신 CameraImage가 알려주는 메타데이터
/// (planes 개수, bytesPerRow, bytesPerPixel)만으로 버퍼 레이아웃을 판별한다.
/// - planes 1개: NV21 단일 버퍼 (camera_android_camerax의 nv21 포맷)
/// - planes 3개: YUV_420_888 (planar/semi-planar, row 패딩 모두 처리)
class CameraImageConverter {
  CameraImageConverter._();

  /// CameraImage를 tightly-packed NV21 바이트로 변환한다.
  /// 지원하지 않는 레이아웃이면 메타데이터를 로그로 남기고 null을 반환한다.
  static Uint8List? toNv21(CameraImage image) {
    try {
      if (image.planes.length == 1) {
        return _repackSinglePlaneNv21(image);
      }
      if (image.planes.length == 3) {
        return _yuv420ToNv21(image);
      }
      _logUnsupported(image);
      return null;
    } catch (e) {
      _logUnsupported(image, error: e);
      return null;
    }
  }

  /// CameraImage를 RGB img.Image로 변환한다. (NV21 경유)
  static img.Image? toRgb(CameraImage image) {
    final nv21 = toNv21(image);
    if (nv21 == null) return null;

    final width = image.width;
    final height = image.height;
    final ySize = width * height;
    final result = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      final yRowOff = y * width;
      final uvRowOff = ySize + (y >> 1) * width;
      for (int x = 0; x < width; x++) {
        final yVal = nv21[yRowOff + x];
        final uvOff = uvRowOff + (x >> 1) * 2;
        final v = nv21[uvOff] - 128;
        final u = nv21[uvOff + 1] - 128;

        final r = (yVal + 1.402 * v).round().clamp(0, 255);
        final g = (yVal - 0.344136 * u - 0.714136 * v).round().clamp(0, 255);
        final b = (yVal + 1.772 * u).round().clamp(0, 255);
        result.setPixelRgb(x, y, r, g, b);
      }
    }
    return result;
  }

  static Uint8List _repackSinglePlaneNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final plane = image.planes[0];
    final bytes = plane.bytes;
    final rowStride = plane.bytesPerRow;
    final nv21Size = width * height * 3 ~/ 2;

    if (rowStride <= width) {
      // 패딩 없음: 그대로 사용 (버퍼가 더 길면 잘라냄)
      return bytes.length == nv21Size
          ? bytes
          : Uint8List.sublistView(bytes, 0, nv21Size);
    }
    // row 패딩 제거 (Y와 VU 영역 모두 같은 stride)
    final out = Uint8List(nv21Size);
    final totalRows = height + height ~/ 2;
    for (int row = 0; row < totalRows; row++) {
      out.setRange(row * width, (row + 1) * width, bytes, row * rowStride);
    }
    return out;
  }

  static Uint8List _yuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final ySize = width * height;
    final out = Uint8List(ySize + width * height ~/ 2);

    final yPlane = image.planes[0];
    for (int row = 0; row < height; row++) {
      final dstOff = row * width;
      out.setRange(dstOff, dstOff + width, yPlane.bytes, row * yPlane.bytesPerRow);
    }

    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final uStride = uPlane.bytesPerRow;
    final vStride = vPlane.bytesPerRow;
    final uPixel = uPlane.bytesPerPixel ?? 1;
    final vPixel = vPlane.bytesPerPixel ?? 1;
    final uvH = height ~/ 2;
    final uvW = width ~/ 2;

    int outIdx = ySize;
    for (int row = 0; row < uvH; row++) {
      for (int col = 0; col < uvW; col++) {
        out[outIdx++] = vPlane.bytes[row * vStride + col * vPixel];
        out[outIdx++] = uPlane.bytes[row * uStride + col * uPixel];
      }
    }
    return out;
  }

  static void _logUnsupported(CameraImage image, {Object? error}) {
    final planesInfo = image.planes
        .map((p) =>
            '(len=${p.bytes.length}, rowStride=${p.bytesPerRow}, pixelStride=${p.bytesPerPixel})')
        .join(', ');
    print('[CameraImageConverter] 변환 실패: '
        'format=${image.format.group}(raw=${image.format.raw}), '
        '${image.width}x${image.height}, planes=${image.planes.length} [$planesInfo]'
        '${error != null ? ', error=$error' : ''}');
  }
}

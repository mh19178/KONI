// lib/services/image_conversion_service.dart

import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

// 必要なクラスは、この2つのパッケージからインポートするのが正解でした
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';


InputImage? inputImageFromCameraImage(CameraImage image, CameraDescription cameraDescription) {
  print('DEBUG: Received image format raw value: ${image.format.raw}');
  final format = InputImageFormatValue.fromRawValue(image.format.raw);

  // サポートされていない、または不明なフォーマットの場合はここで処理を中断
  if (format == null) {
    print('Image format not supported on CameraImage Format Group: ${image.format.group}');
    return null;
  }

  // 全てのプレーンのバイトデータを一つに結合
  final WriteBuffer allBytes = WriteBuffer();
  for (final Plane plane in image.planes) {
    allBytes.putUint8List(plane.bytes);
  }
  final bytes = allBytes.done().buffer.asUint8List();

  final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());

  final imageRotation = InputImageRotationValue.fromRawValue(cameraDescription.sensorOrientation) ?? InputImageRotation.rotation0deg;

  // InputImageMetadataの正しいコンストラクtaーに引数を渡す
  final metadata = InputImageMetadata(
    size: imageSize,
    rotation: imageRotation,
    format: format,
    bytesPerRow: image.planes.first.bytesPerRow,
  );

  return InputImage.fromBytes(bytes: bytes, metadata: metadata);
}
import 'dart:io';
import 'package:exif/exif.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'models.dart';

class PreparedPhoto {
  PreparedPhoto(this.png, this.takenOn);
  final Uint8List png;
  final DateTime? takenOn;
}

DateTime? parseExifDate(String? value) {
  if (value == null) return null;
  final match = RegExp(r'^(\d{4}):(\d{2}):(\d{2})').firstMatch(value);
  if (match == null) return null;
  final y = int.parse(match[1]!),
      m = int.parse(match[2]!),
      d = int.parse(match[3]!);
  final parsed = DateTime(y, m, d);
  return y >= 1900 && parsed.year == y && parsed.month == m && parsed.day == d
      ? parsed
      : null;
}

Uint8List normalizePhoto(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('이 사진 형식을 읽을 수 없어요. JPG 또는 PNG 사진을 선택해 주세요.');
  }
  var image = img.bakeOrientation(decoded);
  if (image.width > 1600 || image.height > 1600) {
    image = img.copyResize(
      image,
      width: image.width >= image.height ? 1600 : null,
      height: image.height > image.width ? 1600 : null,
    );
  }
  return img.encodePng(image);
}

Uint8List trimTransparent(Uint8List bytes) {
  final image = img.decodePng(bytes);
  if (image == null) throw const FormatException('스티커 이미지를 읽지 못했어요.');
  int left = image.width, top = image.height, right = -1, bottom = -1;
  for (final p in image) {
    if (p.a > 16) {
      if (p.x < left) left = p.x;
      if (p.x > right) right = p.x;
      if (p.y < top) top = p.y;
      if (p.y > bottom) bottom = p.y;
    }
  }
  if (right < left) {
    throw const FormatException('사진에서 대상을 찾지 못했어요. 다른 사진을 골라 주세요.');
  }
  return img.encodePng(
    img.copyCrop(
      image,
      x: left,
      y: top,
      width: right - left + 1,
      height: bottom - top + 1,
    ),
  );
}

class PhotoService {
  final picker = ImagePicker();
  Future<XFile?> pick(ImageSource source) => picker.pickImage(
    source: source,
    maxWidth: 1800,
    maxHeight: 1800,
    imageQuality: 95,
    requestFullMetadata: true,
  );
  Future<PreparedPhoto> prepare(XFile file) async {
    if (await file.length() > 30 * 1024 * 1024) {
      throw const FormatException('사진이 너무 커요. 조금 작은 사진을 선택해 주세요.');
    }
    final bytes = await file.readAsBytes();
    DateTime? takenOn;
    try {
      final tags = await readExifFromBytes(bytes);
      takenOn = parseExifDate(tags['EXIF DateTimeOriginal']?.printable);
    } catch (_) {
      /* Missing metadata is presented as an empty date field. */
    }
    final png = await compute(normalizePhoto, bytes);
    return PreparedPhoto(png, takenOn);
  }

  Future<Uint8List> removeBackground(Uint8List png) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('자동 오려내기는 안드로이드 앱에서 사용할 수 있어요.');
    }
    final dir = await getTemporaryDirectory();
    final input = File('${dir.path}/cutout-${uuid.v4()}.png');
    final segmenter = SubjectSegmenter(
      options: SubjectSegmenterOptions(
        enableForegroundBitmap: true,
        enableForegroundConfidenceMask: false,
        enableMultipleSubjects: SubjectResultOptions(
          enableConfidenceMask: false,
          enableSubjectBitmap: false,
        ),
      ),
    );
    try {
      await input.writeAsBytes(png);
      final result = await segmenter.processImage(
        InputImage.fromFilePath(input.path),
      );
      final foreground = result.foregroundBitmap;
      if (foreground == null || foreground.isEmpty) {
        throw const FormatException('대상을 분리하지 못했어요. 다른 사진으로 다시 시도해 주세요.');
      }
      return await compute(trimTransparent, foreground);
    } finally {
      await segmenter.close();
      if (await input.exists()) await input.delete();
    }
  }
}
